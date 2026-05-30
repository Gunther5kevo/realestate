import React, { useEffect, useState, useCallback } from 'react'
import {
  collection, query, where, orderBy, limit,
  startAfter, getDocs, doc, updateDoc,
  serverTimestamp, getCountFromServer
} from 'firebase/firestore'
import { db } from '../firebase/config'
import {
  UserCheck, Search, CheckCircle, XCircle, Star,
  ChevronLeft, ChevronRight, RefreshCw, X,
  Building2, MapPin, Phone, Mail, Calendar,
  BadgeCheck, ShieldOff, BarChart2, Eye,
  AlertTriangle
} from 'lucide-react'
import { format } from 'date-fns'
import clsx from 'clsx'

// ─── Constants ────────────────────────────────────────────────────────────────
const PAGE_SIZE = 15

const VERIFIED_OPTIONS = [
  { value: 'all',   label: 'All Agents' },
  { value: 'true',  label: 'Verified' },
  { value: 'false', label: 'Unverified' },
]

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtDate(ts) {
  if (!ts) return '—'
  try {
    const d = ts.toDate ? ts.toDate() : new Date(ts)
    return format(d, 'MMM d, yyyy')
  } catch { return '—' }
}

function fmtKES(n) {
  if (!n) return '—'
  if (n >= 1_000_000) return `KES ${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000)     return `KES ${(n / 1_000).toFixed(0)}K`
  return `KES ${n}`
}

function Skeleton({ className }) {
  return <div className={clsx('animate-pulse bg-neutral-variant rounded', className)} />
}

function initials(name, email) {
  if (name) return name.split(' ').map(p => p[0]).join('').toUpperCase().slice(0, 2)
  if (email) return email.slice(0, 2).toUpperCase()
  return 'AG'
}

// ─── Verify Badge ──────────────────────────────────────────────────────────────
function VerifyBadge({ isVerified }) {
  return isVerified
    ? <span className="badge badge-active"><BadgeCheck size={9} />Verified</span>
    : <span className="badge badge-pending">Unverified</span>
}

// ─── Agent Avatar ─────────────────────────────────────────────────────────────
function AgentAvatar({ agent, size = 'md' }) {
  const sz = {
    sm: 'w-8 h-8 text-xs',
    md: 'w-10 h-10 text-sm',
    lg: 'w-14 h-14 text-base',
  }[size]

  return agent.avatarUrl ? (
    <img
      src={agent.avatarUrl}
      alt={agent.displayName}
      className={clsx('rounded-xl object-cover flex-shrink-0', sz)}
    />
  ) : (
    <div className={clsx(
      'rounded-xl bg-primary-surface text-primary font-bold flex items-center justify-center flex-shrink-0',
      sz
    )}>
      {initials(agent.displayName, agent.email)}
    </div>
  )
}

// ─── Stat Pill ────────────────────────────────────────────────────────────────
function StatPill({ label, value, icon: Icon, color }) {
  return (
    <div className="flex items-center gap-2 bg-neutral-variant rounded-lg px-3 py-2">
      <Icon size={13} className={color} />
      <div>
        <p className="text-xs text-text-tertiary leading-none">{label}</p>
        <p className="text-sm font-bold text-text-primary mt-0.5">{value}</p>
      </div>
    </div>
  )
}

// ─── Listing Mini Card ────────────────────────────────────────────────────────
function ListingMiniCard({ listing }) {
  return (
    <div className="flex items-center gap-3 p-3 rounded-lg border border-neutral-border hover:bg-neutral-variant transition-colors">
      {listing.imageUrls?.[0] ? (
        <img
          src={listing.imageUrls[0]}
          alt={listing.title}
          className="w-12 h-12 rounded-lg object-cover flex-shrink-0"
        />
      ) : (
        <div className="w-12 h-12 rounded-lg bg-neutral-variant flex items-center justify-center flex-shrink-0">
          <Building2 size={16} className="text-text-tertiary" />
        </div>
      )}
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-text-primary truncate">{listing.title || '—'}</p>
        <div className="flex items-center gap-1 text-xs text-text-tertiary mt-0.5">
          <MapPin size={10} />
          <span className="truncate">{typeof listing.location === 'object' ? [listing.location?.city, listing.location?.country].filter(Boolean).join(', ') || '—' : listing.location || '—'}</span>
        </div>
        <p className="text-xs font-semibold text-accent mt-0.5">
          {fmtKES(listing.price)}
        </p>
      </div>
      <div className="flex-shrink-0">
        {listing.isApproved
          ? <span className="badge badge-active text-2xs">Active</span>
          : <span className="badge badge-pending text-2xs">Pending</span>
        }
      </div>
    </div>
  )
}

// ─── Agent Drawer ─────────────────────────────────────────────────────────────
function AgentDrawer({ agent, onClose, onAction, actionLoading }) {
  const [listings, setListings] = useState([])
  const [listingsLoading, setListingsLoading] = useState(true)
  const [activeTab, setActiveTab] = useState('details') // 'details' | 'listings'

  useEffect(() => {
    if (agent) loadAgentListings()
  }, [agent])

  async function loadAgentListings() {
    setListingsLoading(true)
    try {
      const q = query(
        collection(db, 'properties'),
        where('agentId', '==', agent.userId || agent.id),
        orderBy('createdAt', 'desc'),
        limit(10)
      )
      const snap = await getDocs(q)
      setListings(snap.docs.map(d => ({ id: d.id, ...d.data() })))
    } catch (err) {
      console.error(err)
    } finally {
      setListingsLoading(false)
    }
  }

  if (!agent) return null

  const stats = [
    { label: 'Listings',  value: agent.totalListings || 0,                         icon: Building2, color: 'text-primary' },
    { label: 'Sold',      value: agent.soldCount || 0,                               icon: BarChart2, color: 'text-status-error' },
    { label: 'Rating',    value: agent.rating ? `${agent.rating.toFixed(1)}★` : '—', icon: Star,     color: 'text-status-pending' },
    { label: 'Reviews',   value: agent.reviewCount || 0,                             icon: Calendar,  color: 'text-accent' },
  ]

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/25 animate-fade-in" onClick={onClose} />
      <div className="relative w-full max-w-md bg-neutral-surface border-l border-neutral-border h-full flex flex-col shadow-lg">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-neutral-border sticky top-0 bg-neutral-surface z-10">
          <h3 className="text-md font-semibold text-text-primary">Agent Profile</h3>
          <button onClick={onClose} className="text-text-tertiary hover:text-text-primary">
            <X size={18} />
          </button>
        </div>

        {/* Profile hero */}
        <div className="p-5 border-b border-neutral-border">
          <div className="flex items-start gap-4 mb-4">
            <AgentAvatar agent={agent} size="lg" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <h4 className="text-lg font-semibold text-text-primary">
                  {agent.displayName || 'No name'}
                </h4>
                <VerifyBadge isVerified={agent.isVerified} />
              </div>
              <p className="text-sm text-text-secondary truncate">{agent.email || '—'}</p>
              {agent.agency && (
                <p className="text-xs text-text-tertiary mt-0.5">{agent.agency}</p>
              )}
              <p className="text-xs text-text-tertiary mt-1">Joined {fmtDate(agent.memberSince || agent.createdAt)}</p>
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 gap-2">
            {stats.map(s => <StatPill key={s.label} {...s} />)}
          </div>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-neutral-border">
          {['details', 'listings'].map(tab => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={clsx(
                'flex-1 py-3 text-sm font-medium capitalize transition-colors',
                activeTab === tab
                  ? 'text-primary border-b-2 border-primary'
                  : 'text-text-secondary hover:text-text-primary'
              )}
            >
              {tab === 'listings' ? `Listings (${listings.length})` : 'Details'}
            </button>
          ))}
        </div>

        {/* Tab content */}
        <div className="flex-1 overflow-y-auto p-5">
          {activeTab === 'details' && (
            <div className="space-y-5">
              {/* Contact info */}
              <div className="space-y-1">
                <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">
                  Contact
                </p>
                {[
                  { label: 'Email',   value: agent.email || '—',   icon: Mail },
                  { label: 'Phone',   value: agent.phone || '—',   icon: Phone },
                  { label: 'Agency',  value: agent.agency || '—',  icon: Building2 },
                  { label: 'License', value: agent.licenseNumber || '—', icon: BadgeCheck },
                ].map(({ label, value, icon: Icon }) => (
                  <div key={label} className="flex items-center justify-between py-2.5 border-b border-neutral-divider last:border-0">
                    <div className="flex items-center gap-2 text-text-secondary">
                      <Icon size={13} />
                      <span className="text-sm">{label}</span>
                    </div>
                    <span className="text-sm font-medium text-text-primary text-right max-w-[200px] truncate">
                      {value}
                    </span>
                  </div>
                ))}
              </div>

              {/* Bio */}
              {agent.bio && (
                <div>
                  <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-2">Bio</p>
                  <p className="text-sm text-text-secondary leading-relaxed">{agent.bio}</p>
                </div>
              )}

              {/* Actions */}
              <div className="space-y-2 pt-1">
                <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">Actions</p>
                {!agent.isVerified ? (
                  <button
                    onClick={() => onAction('verify', agent)}
                    disabled={actionLoading}
                    className="w-full btn-success border border-green-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
                  >
                    <BadgeCheck size={15} /> Verify Agent
                  </button>
                ) : (
                  <button
                    onClick={() => onAction('unverify', agent)}
                    disabled={actionLoading}
                    className="w-full btn-ghost border border-neutral-border rounded-lg py-2.5 justify-center disabled:opacity-50"
                  >
                    <ShieldOff size={15} /> Remove Verification
                  </button>
                )}
              </div>
            </div>
          )}

          {activeTab === 'listings' && (
            <div className="space-y-3">
              {listingsLoading ? (
                Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="flex gap-3 p-3 border border-neutral-border rounded-lg">
                    <Skeleton className="w-12 h-12 rounded-lg flex-shrink-0" />
                    <div className="flex-1 space-y-2">
                      <Skeleton className="h-4 w-3/4" />
                      <Skeleton className="h-3 w-1/2" />
                    </div>
                  </div>
                ))
              ) : listings.length === 0 ? (
                <div className="empty-state py-10">
                  <Building2 size={24} className="text-text-tertiary mb-2" />
                  <p className="text-sm text-text-secondary">No listings yet</p>
                </div>
              ) : (
                listings.map(listing => (
                  <ListingMiniCard key={listing.id} listing={listing} />
                ))
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ─── Confirm Modal ────────────────────────────────────────────────────────────
function ConfirmModal({ title, message, confirmLabel, confirmClass, onConfirm, onClose, loading }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/30 animate-fade-in">
      <div className="bg-neutral-surface rounded-lg border border-neutral-border w-full max-w-sm shadow-lg animate-slide-up">
        <div className="p-5 border-b border-neutral-border flex items-center justify-between">
          <h3 className="text-md font-semibold text-text-primary">{title}</h3>
          <button onClick={onClose} className="text-text-tertiary hover:text-text-primary">
            <X size={18} />
          </button>
        </div>
        <div className="p-5">
          <div className="flex items-start gap-3 mb-5">
            <div className="w-9 h-9 rounded-lg bg-status-pending-bg flex items-center justify-center flex-shrink-0">
              <AlertTriangle size={16} className="text-status-pending" />
            </div>
            <p className="text-sm text-text-secondary leading-relaxed">{message}</p>
          </div>
          <div className="flex gap-3">
            <button onClick={onClose} className="flex-1 btn-ghost border border-neutral-border rounded py-2">
              Cancel
            </button>
            <button
              onClick={onConfirm}
              disabled={loading}
              className={clsx('flex-1 rounded py-2 text-sm font-semibold flex items-center justify-center gap-1.5 disabled:opacity-50', confirmClass)}
            >
              {loading
                ? <span className="w-4 h-4 border-2 border-current/30 border-t-current rounded-full animate-spin" />
                : confirmLabel}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

// ─── Main Component ───────────────────────────────────────────────────────────
export default function AgentsPage() {
  const [agents, setAgents] = useState([])
  const [loading, setLoading] = useState(true)
  const [total, setTotal] = useState(0)
  const [search, setSearch] = useState('')
  const [verifiedFilter, setVerifiedFilter] = useState('all')
  const [page, setPage] = useState(0)
  const [cursors, setCursors] = useState([null])
  const [selectedAgent, setSelectedAgent] = useState(null)
  const [confirmModal, setConfirmModal] = useState(null)
  const [actionLoading, setActionLoading] = useState(false)
  const [toast, setToast] = useState(null)

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3000)
  }

  const buildConstraints = useCallback(() => {
    const c = []
    if (verifiedFilter === 'true')  c.push(where('isVerified', '==', true))
    if (verifiedFilter === 'false') c.push(where('isVerified', '==', false))
    c.push(orderBy('memberSince', 'desc'))
    return c
  }, [verifiedFilter])

  useEffect(() => {
    const loadCount = async () => {
      try {
        // Count query without orderBy to avoid composite index requirement
        const countConstraints = []
        if (verifiedFilter === 'true')  countConstraints.push(where('isVerified', '==', true))
        if (verifiedFilter === 'false') countConstraints.push(where('isVerified', '==', false))
        const q = query(collection(db, 'agents'), ...countConstraints)
        const snap = await getCountFromServer(q)
        setTotal(snap.data().count)
      } catch { setTotal(0) }
    }
    loadCount()
  }, [buildConstraints])

  useEffect(() => { loadPage() }, [page, verifiedFilter])
  useEffect(() => { setPage(0); setCursors([null]) }, [verifiedFilter])

  async function loadPage() {
    setLoading(true)
    try {
      const constraints = buildConstraints()
      const cursor = cursors[page]
      const q = cursor
        ? query(collection(db, 'agents'), ...constraints, startAfter(cursor), limit(PAGE_SIZE))
        : query(collection(db, 'agents'), ...constraints, limit(PAGE_SIZE))
      const snap = await getDocs(q)
      setAgents(snap.docs.map(d => ({ id: d.id, ...d.data() })))
      if (snap.docs.length === PAGE_SIZE) {
        setCursors(prev => {
          const next = [...prev]
          next[page + 1] = snap.docs[snap.docs.length - 1]
          return next
        })
      }
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  const ACTION_CONFIRM = {
    verify: {
      title: 'Verify Agent',
      message: (a) => `Grant verified status to ${a.displayName || a.email}? They will receive a verified badge on all their listings.`,
      confirmLabel: 'Verify Agent',
      confirmClass: 'bg-status-active text-white hover:bg-green-700',
    },
    unverify: {
      title: 'Remove Verification',
      message: (a) => `Remove verified badge from ${a.displayName || a.email}? Their listings will no longer show the verified mark.`,
      confirmLabel: 'Remove Verification',
      confirmClass: 'bg-status-error text-white',
    },
  }

  function handleAction(action, agent) {
    setConfirmModal({ action, agent })
  }

  async function executeAction() {
    if (!confirmModal) return
    const { action, agent } = confirmModal
    setActionLoading(true)
    try {
      const agentRef = doc(db, 'agents', agent.id)
      const userRef  = doc(db, 'users', agent.userId || agent.id)

      if (action === 'verify') {
        await updateDoc(agentRef, { isVerified: true, verifiedAt: serverTimestamp() })
        await updateDoc(userRef,  { isVerified: true })
        showToast(`${agent.displayName || agent.email} is now verified.`)
      } else if (action === 'unverify') {
        await updateDoc(agentRef, { isVerified: false, verifiedAt: null })
        await updateDoc(userRef,  { isVerified: false })
        showToast(`Verification removed from ${agent.displayName || agent.email}.`, 'error')
      }

      setConfirmModal(null)
      setSelectedAgent(null)
      await loadPage()
    } catch (err) {
      console.error(err)
      showToast('Action failed. Please try again.', 'error')
    } finally {
      setActionLoading(false)
    }
  }

  // ─── Client search ─────────────────────────────────────────────────────────
  const filtered = search.trim()
    ? agents.filter(a =>
        [a.displayName, a.email, a.phone, a.agency, a.licenseNumber]
          .some(v => v?.toLowerCase().includes(search.toLowerCase()))
      )
    : agents

  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h1 className="page-title">Agents</h1>
          <p className="page-subtitle">{total.toLocaleString()} registered agents</p>
        </div>
      </div>

      {/* Filters */}
      <div className="filter-bar">
        <div className="relative flex-1 min-w-48 max-w-sm">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" />
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search name, email, agency…"
            className="search-input pl-9"
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-text-tertiary hover:text-text-primary">
              <X size={14} />
            </button>
          )}
        </div>
        <select value={verifiedFilter} onChange={e => setVerifiedFilter(e.target.value)} className="filter-select">
          {VERIFIED_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <button onClick={loadPage} className="btn-ghost border border-neutral-border rounded px-3 py-2">
          <RefreshCw size={14} />
        </button>
      </div>

      {/* Table */}
      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Agent</th>
                <th>Agency</th>
                <th>Phone</th>
                <th>Listings</th>
                <th>Rating</th>
                <th>Joined</th>
                <th>Verified</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i}>
                    {[220, 120, 100, 60, 60, 90, 80, 110].map((w, j) => (
                      <td key={j}><Skeleton className="h-4" style={{ width: w }} /></td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <UserCheck size={28} className="text-text-tertiary mb-2" />
                      <p className="text-sm text-text-secondary">No agents found</p>
                      <p className="text-xs text-text-tertiary mt-1">Try adjusting your filters.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(agent => (
                  <tr key={agent.id}>
                    {/* Agent */}
                    <td>
                      <div className="flex items-center gap-3">
                        <AgentAvatar agent={agent} size="sm" />
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-text-primary truncate max-w-[160px]">
                            {agent.displayName || 'No name'}
                          </p>
                          <p className="text-xs text-text-tertiary truncate max-w-[160px]">{agent.email}</p>
                        </div>
                      </div>
                    </td>
                    {/* Agency */}
                    <td>
                      <span className="text-sm text-text-secondary truncate max-w-[120px] block">
                        {agent.agency || '—'}
                      </span>
                    </td>
                    {/* Phone */}
                    <td>
                      <span className="text-sm text-text-secondary">{agent.phone || '—'}</span>
                    </td>
                    {/* Listings */}
                    <td>
                      <span className="text-sm font-semibold text-text-primary">
                        {agent.totalListings ?? '—'}
                      </span>
                    </td>
                    {/* Rating */}
                    <td>
                      {agent.rating ? (
                        <div className="flex items-center gap-1">
                          <Star size={12} className="text-status-pending fill-status-pending" />
                          <span className="text-sm font-semibold text-text-primary">
                            {agent.rating.toFixed(1)}
                          </span>
                        </div>
                      ) : (
                        <span className="text-sm text-text-tertiary">—</span>
                      )}
                    </td>
                    {/* Joined */}
                    <td>
                      <span className="text-sm text-text-secondary">{fmtDate(agent.memberSince || agent.createdAt)}</span>
                    </td>
                    {/* Verified */}
                    <td><VerifyBadge isVerified={agent.isVerified} /></td>
                    {/* Actions */}
                    <td>
                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => setSelectedAgent(agent)}
                          className="btn-ghost px-2 py-1.5 rounded"
                          title="View profile"
                        >
                          <Eye size={14} />
                        </button>
                        {!agent.isVerified ? (
                          <button
                            onClick={() => handleAction('verify', agent)}
                            className="btn-success"
                            title="Verify"
                            disabled={actionLoading}
                          >
                            <BadgeCheck size={13} /> Verify
                          </button>
                        ) : (
                          <button
                            onClick={() => handleAction('unverify', agent)}
                            className="btn-ghost border border-neutral-border"
                            title="Remove verification"
                            disabled={actionLoading}
                          >
                            <ShieldOff size={13} />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {!loading && total > PAGE_SIZE && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-neutral-border">
            <p className="text-xs text-text-tertiary">
              Showing {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, total)} of {total.toLocaleString()}
            </p>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setPage(p => Math.max(0, p - 1))}
                disabled={page === 0}
                className="btn-ghost border border-neutral-border rounded px-2 py-1.5 disabled:opacity-40"
              >
                <ChevronLeft size={15} />
              </button>
              <span className="text-xs text-text-secondary px-1">{page + 1} / {totalPages}</span>
              <button
                onClick={() => setPage(p => p + 1)}
                disabled={page >= totalPages - 1}
                className="btn-ghost border border-neutral-border rounded px-2 py-1.5 disabled:opacity-40"
              >
                <ChevronRight size={15} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Agent Drawer */}
      {selectedAgent && (
        <AgentDrawer
          agent={selectedAgent}
          onClose={() => setSelectedAgent(null)}
          onAction={handleAction}
          actionLoading={actionLoading}
        />
      )}

      {/* Confirm Modal */}
      {confirmModal && (() => {
        const cfg = ACTION_CONFIRM[confirmModal.action]
        return (
          <ConfirmModal
            title={cfg.title}
            message={cfg.message(confirmModal.agent)}
            confirmLabel={cfg.confirmLabel}
            confirmClass={cfg.confirmClass}
            onConfirm={executeAction}
            onClose={() => setConfirmModal(null)}
            loading={actionLoading}
          />
        )
      })()}

      {/* Toast */}
      {toast && (
        <div className={clsx(
          'fixed bottom-6 right-6 z-50 flex items-center gap-2.5 px-4 py-3 rounded-lg shadow-lg text-sm font-medium animate-slide-up',
          toast.type === 'error' ? 'bg-status-error text-white' : 'bg-text-primary text-white'
        )}>
          {toast.type === 'error' ? <XCircle size={15} /> : <CheckCircle size={15} />}
          {toast.msg}
        </div>
      )}
    </div>
  )
}