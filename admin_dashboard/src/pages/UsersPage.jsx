import React, { useEffect, useState, useCallback } from 'react'
import {
  collection, query, where, orderBy, limit,
  startAfter, getDocs, doc, updateDoc,
  serverTimestamp, getCountFromServer, setDoc
} from 'firebase/firestore'
import { db } from '../firebase/config'
import {
  Users, Search, UserCheck, Ban, ChevronLeft,
  ChevronRight, RefreshCw, X, CheckCircle, XCircle,
  Shield, Mail, Phone, Calendar, MoreHorizontal,
  AlertTriangle
} from 'lucide-react'
import { format } from 'date-fns'
import clsx from 'clsx'

// ─── Constants ────────────────────────────────────────────────────────────────
const PAGE_SIZE = 20

const ROLE_OPTIONS = [
  { value: 'all',   label: 'All Roles' },
  { value: 'user',  label: 'Users' },
  { value: 'agent', label: 'Agents' },
  { value: 'admin', label: 'Admins' },
]

const STATUS_OPTIONS = [
  { value: 'all',      label: 'All Status' },
  { value: 'active',   label: 'Active' },
  { value: 'suspended', label: 'Suspended' },
]

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtDate(ts) {
  if (!ts) return '—'
  try {
    const d = ts.toDate ? ts.toDate() : new Date(ts)
    return format(d, 'MMM d, yyyy')
  } catch { return '—' }
}

function Skeleton({ className }) {
  return <div className={clsx('animate-pulse bg-neutral-variant rounded', className)} />
}

function initials(name, email) {
  if (name) return name.split(' ').map(p => p[0]).join('').toUpperCase().slice(0, 2)
  if (email) return email.slice(0, 2).toUpperCase()
  return 'U'
}

// ─── Role Badge ───────────────────────────────────────────────────────────────
function RoleBadge({ role }) {
  const map = {
    admin: 'badge-error',
    agent: 'badge-primary',
    user:  'badge-neutral',
  }
  return <span className={clsx('badge', map[role] ?? 'badge-neutral')}>{role}</span>
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
function StatusBadge({ isActive }) {
  return isActive === false
    ? <span className="badge badge-error"><Ban size={9} />Suspended</span>
    : <span className="badge badge-active"><CheckCircle size={9} />Active</span>
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
function UserAvatar({ user, size = 'md' }) {
  const sz = size === 'lg' ? 'w-12 h-12 text-base' : 'w-8 h-8 text-xs'
  return user.photoURL ? (
    <img
      src={user.photoURL}
      alt={user.displayName}
      className={clsx('rounded-lg object-cover flex-shrink-0', sz)}
    />
  ) : (
    <div className={clsx(
      'rounded-lg bg-primary-surface text-primary font-bold flex items-center justify-center flex-shrink-0',
      sz
    )}>
      {initials(user.displayName, user.email)}
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
              {loading ? (
                <span className="w-4 h-4 border-2 border-current/30 border-t-current rounded-full animate-spin" />
              ) : confirmLabel}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

// ─── User Drawer ──────────────────────────────────────────────────────────────
function UserDrawer({ user, onClose, onAction, actionLoading }) {
  if (!user) return null

  const fields = [
    { label: 'Email',      value: user.email,                     icon: Mail },
    { label: 'Phone',      value: user.phone || '—',              icon: Phone },
    { label: 'Role',       value: user.role,                      icon: Shield },
    { label: 'Joined',     value: fmtDate(user.createdAt),        icon: Calendar },
    { label: 'Last Login', value: fmtDate(user.lastLoginAt),      icon: Calendar },
    { label: 'UID',        value: user.id,                        icon: null },
  ]

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/25 animate-fade-in" onClick={onClose} />
      <div className="relative w-full max-w-md bg-neutral-surface border-l border-neutral-border
                      h-full overflow-y-auto shadow-lg flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-neutral-border sticky top-0 bg-neutral-surface z-10">
          <h3 className="text-md font-semibold text-text-primary">User Detail</h3>
          <button onClick={onClose} className="text-text-tertiary hover:text-text-primary">
            <X size={18} />
          </button>
        </div>

        <div className="p-5 flex-1 space-y-5">
          {/* Profile */}
          <div className="flex items-center gap-4">
            <UserAvatar user={user} size="lg" />
            <div>
              <h4 className="text-lg font-semibold text-text-primary">
                {user.displayName || 'No name'}
              </h4>
              <p className="text-sm text-text-secondary">{user.email}</p>
              <div className="flex items-center gap-2 mt-1.5">
                <RoleBadge role={user.role} />
                <StatusBadge isActive={user.isActive} />
              </div>
            </div>
          </div>

          {/* Fields */}
          <div className="space-y-1">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">Details</p>
            {fields.map(({ label, value, icon: Icon }) => (
              <div key={label} className="flex items-center justify-between py-2.5 border-b border-neutral-divider last:border-0">
                <div className="flex items-center gap-2 text-text-secondary">
                  {Icon && <Icon size={13} />}
                  <span className="text-sm">{label}</span>
                </div>
                <span className={clsx(
                  'text-sm font-medium text-text-primary text-right max-w-[200px] truncate',
                  label === 'UID' && 'font-mono text-xs text-text-tertiary'
                )}>
                  {value}
                </span>
              </div>
            ))}
          </div>

          {/* Stats */}
          {(user.role === 'agent') && (
            <div className="grid grid-cols-3 gap-3">
              {[
                { label: 'Listings',  value: user.listingCount ?? 0 },
                { label: 'Bookings',  value: user.bookingCount ?? 0 },
                { label: 'Reviews',   value: user.reviewCount ?? 0 },
              ].map(s => (
                <div key={s.label} className="bg-neutral-variant rounded-lg p-3 text-center">
                  <p className="text-lg font-bold text-text-primary">{s.value}</p>
                  <p className="text-xs text-text-tertiary mt-0.5">{s.label}</p>
                </div>
              ))}
            </div>
          )}

          {/* Actions */}
          <div className="space-y-2 pt-2">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">Actions</p>

            {user.role === 'user' && (
              <button
                onClick={() => onAction('upgrade', user)}
                disabled={actionLoading}
                className="w-full btn-accent border border-green-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
              >
                <UserCheck size={15} /> Upgrade to Agent
              </button>
            )}
            {user.role === 'agent' && (
              <button
                onClick={() => onAction('downgrade', user)}
                disabled={actionLoading}
                className="w-full btn-ghost border border-neutral-border rounded-lg py-2.5 justify-center disabled:opacity-50"
              >
                <Users size={15} /> Downgrade to User
              </button>
            )}
            {user.isActive !== false ? (
              <button
                onClick={() => onAction('suspend', user)}
                disabled={actionLoading || user.role === 'admin'}
                className="w-full btn-danger border border-red-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
              >
                <Ban size={15} /> Suspend Account
              </button>
            ) : (
              <button
                onClick={() => onAction('reinstate', user)}
                disabled={actionLoading}
                className="w-full btn-success border border-green-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
              >
                <CheckCircle size={15} /> Reinstate Account
              </button>
            )}
            {user.role === 'admin' && (
              <p className="text-xs text-text-tertiary text-center pt-1">Admin accounts cannot be suspended.</p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

// ─── Main Component ───────────────────────────────────────────────────────────
export default function UsersPage() {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [total, setTotal] = useState(0)
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [page, setPage] = useState(0)
  const [cursors, setCursors] = useState([null])
  const [selectedUser, setSelectedUser] = useState(null)
  const [confirmModal, setConfirmModal] = useState(null) // { action, user }
  const [actionLoading, setActionLoading] = useState(false)
  const [toast, setToast] = useState(null)

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3000)
  }

  // ─── Build constraints ─────────────────────────────────────────────────────
  const buildConstraints = useCallback(() => {
    const c = []
    if (roleFilter !== 'all')         c.push(where('role', '==', roleFilter))
    if (statusFilter === 'active')    c.push(where('isActive', '!=', false))
    if (statusFilter === 'suspended') c.push(where('isActive', '==', false))
    c.push(orderBy('createdAt', 'desc'))
    return c
  }, [roleFilter, statusFilter])

  // ─── Count ────────────────────────────────────────────────────────────────
  useEffect(() => {
    const loadCount = async () => {
      try {
        const q = query(collection(db, 'users'), ...buildConstraints())
        const snap = await getCountFromServer(q)
        setTotal(snap.data().count)
      } catch { setTotal(0) }
    }
    loadCount()
  }, [buildConstraints])

  // ─── Load page ────────────────────────────────────────────────────────────
  useEffect(() => { loadPage() }, [page, roleFilter, statusFilter])

  useEffect(() => { setPage(0); setCursors([null]) }, [roleFilter, statusFilter])

  async function loadPage() {
    setLoading(true)
    try {
      const constraints = buildConstraints()
      const cursor = cursors[page]
      const q = cursor
        ? query(collection(db, 'users'), ...constraints, startAfter(cursor), limit(PAGE_SIZE))
        : query(collection(db, 'users'), ...constraints, limit(PAGE_SIZE))
      const snap = await getDocs(q)
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })))
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
    upgrade: {
      title: 'Upgrade to Agent',
      message: (u) => `Upgrade ${u.displayName || u.email} to agent role? They will gain access to agent features and can list properties.`,
      confirmLabel: 'Upgrade to Agent',
      confirmClass: 'bg-accent text-white hover:bg-accent-light',
    },
    downgrade: {
      title: 'Downgrade to User',
      message: (u) => `Downgrade ${u.displayName || u.email} back to user role? Their listings will remain but they lose agent privileges.`,
      confirmLabel: 'Downgrade',
      confirmClass: 'bg-status-pending text-white',
    },
    suspend: {
      title: 'Suspend Account',
      message: (u) => `Suspend ${u.displayName || u.email}? They will be blocked from logging in immediately.`,
      confirmLabel: 'Suspend Account',
      confirmClass: 'bg-status-error text-white',
    },
    reinstate: {
      title: 'Reinstate Account',
      message: (u) => `Reinstate ${u.displayName || u.email}? They will regain full access to the platform.`,
      confirmLabel: 'Reinstate',
      confirmClass: 'bg-status-active text-white',
    },
  }

  function handleAction(action, user) {
    setConfirmModal({ action, user })
  }

  async function executeAction() {
    if (!confirmModal) return
    const { action, user } = confirmModal
    setActionLoading(true)
    const ref = doc(db, 'users', user.id)
    try {
      switch (action) {
        case 'upgrade':
          await updateDoc(ref, { role: 'agent', upgradedAt: serverTimestamp() })
          // Create agent doc if not exists
          await setDoc(doc(db, 'agents', user.id), {
            userId: user.id,
            displayName: user.displayName || '',
            email: user.email || '',
            isVerified: false,
            createdAt: serverTimestamp(),
          }, { merge: true })
          showToast(`${user.displayName || user.email} upgraded to agent.`)
          break
        case 'downgrade':
          await updateDoc(ref, { role: 'user' })
          showToast(`${user.displayName || user.email} downgraded to user.`)
          break
        case 'suspend':
          await updateDoc(ref, { isActive: false, suspendedAt: serverTimestamp() })
          showToast(`Account suspended.`, 'error')
          break
        case 'reinstate':
          await updateDoc(ref, { isActive: true, reinstatedAt: serverTimestamp() })
          showToast(`Account reinstated.`)
          break
      }
      setConfirmModal(null)
      setSelectedUser(null)
      await loadPage()
    } catch (err) {
      console.error(err)
      showToast('Action failed. Please try again.', 'error')
    } finally {
      setActionLoading(false)
    }
  }

  // ─── Client-side search ────────────────────────────────────────────────────
  const filtered = search.trim()
    ? users.filter(u =>
        [u.displayName, u.email, u.phone, u.id]
          .some(v => v?.toLowerCase().includes(search.toLowerCase()))
      )
    : users

  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h1 className="page-title">Users</h1>
          <p className="page-subtitle">{total.toLocaleString()} registered accounts</p>
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
            placeholder="Search name, email, phone, UID…"
            className="search-input pl-9"
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-text-tertiary hover:text-text-primary">
              <X size={14} />
            </button>
          )}
        </div>
        <select value={roleFilter} onChange={e => setRoleFilter(e.target.value)} className="filter-select">
          {ROLE_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)} className="filter-select">
          {STATUS_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
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
                <th>User</th>
                <th>Role</th>
                <th>Phone</th>
                <th>Joined</th>
                <th>Last Login</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i}>
                    {[240, 70, 100, 90, 90, 80, 130].map((w, j) => (
                      <td key={j}><Skeleton className="h-4" style={{ width: w }} /></td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={7}>
                    <div className="empty-state">
                      <Users size={28} className="text-text-tertiary mb-2" />
                      <p className="text-sm text-text-secondary">No users found</p>
                      <p className="text-xs text-text-tertiary mt-1">Try adjusting your filters.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(user => (
                  <tr key={user.id}>
                    {/* User */}
                    <td>
                      <div className="flex items-center gap-3">
                        <UserAvatar user={user} />
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-text-primary truncate max-w-[180px]">
                            {user.displayName || 'No name'}
                          </p>
                          <p className="text-xs text-text-tertiary truncate max-w-[180px]">{user.email}</p>
                        </div>
                      </div>
                    </td>
                    {/* Role */}
                    <td><RoleBadge role={user.role} /></td>
                    {/* Phone */}
                    <td><span className="text-sm text-text-secondary">{user.phone || '—'}</span></td>
                    {/* Joined */}
                    <td><span className="text-sm text-text-secondary">{fmtDate(user.createdAt)}</span></td>
                    {/* Last Login */}
                    <td><span className="text-sm text-text-secondary">{fmtDate(user.lastLoginAt)}</span></td>
                    {/* Status */}
                    <td><StatusBadge isActive={user.isActive} /></td>
                    {/* Actions */}
                    <td>
                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => setSelectedUser(user)}
                          className="btn-ghost px-2 py-1.5 rounded"
                          title="View details"
                        >
                          <MoreHorizontal size={15} />
                        </button>
                        {user.role === 'user' && (
                          <button
                            onClick={() => handleAction('upgrade', user)}
                            className="btn-accent"
                            title="Upgrade to Agent"
                          >
                            <UserCheck size={13} /> Agent
                          </button>
                        )}
                        {user.isActive !== false ? (
                          <button
                            onClick={() => handleAction('suspend', user)}
                            disabled={user.role === 'admin'}
                            className="btn-danger disabled:opacity-30"
                            title="Suspend"
                          >
                            <Ban size={13} />
                          </button>
                        ) : (
                          <button
                            onClick={() => handleAction('reinstate', user)}
                            className="btn-success"
                            title="Reinstate"
                          >
                            <CheckCircle size={13} />
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

      {/* User Drawer */}
      {selectedUser && (
        <UserDrawer
          user={selectedUser}
          onClose={() => setSelectedUser(null)}
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
            message={cfg.message(confirmModal.user)}
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