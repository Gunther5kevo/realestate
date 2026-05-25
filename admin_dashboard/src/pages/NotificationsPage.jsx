import React, { useEffect, useState } from 'react'
import {
  collection, addDoc, serverTimestamp, query,
  orderBy, limit, getDocs, where
} from 'firebase/firestore'
import { db } from '../firebase/config'
import {
  Bell, Send, Users, UserCheck, User,
  CheckCircle, XCircle, Search, X,
  Megaphone, Clock, ChevronDown, ChevronUp,
  Info, AlertTriangle, Star, Tag
} from 'lucide-react'
import { format } from 'date-fns'
import clsx from 'clsx'

// ─── Constants ────────────────────────────────────────────────────────────────
const AUDIENCE_OPTIONS = [
  {
    value: 'all',
    label: 'All Users',
    description: 'Every registered user on the platform',
    icon: Users,
    color: 'text-primary',
    bg: 'bg-primary-surface',
    border: 'border-primary',
  },
  {
    value: 'agents',
    label: 'All Agents',
    description: 'All registered agents (verified and unverified)',
    icon: UserCheck,
    color: 'text-accent',
    bg: 'bg-accent-surface',
    border: 'border-accent',
  },
  {
    value: 'specific',
    label: 'Specific User',
    description: 'Target a single user by email or UID',
    icon: User,
    color: 'text-status-pending',
    bg: 'bg-status-pending-bg',
    border: 'border-status-pending',
  },
]

const NOTIFICATION_TYPES = [
  { value: 'general',     label: 'General',     icon: Bell,          color: 'text-text-secondary' },
  { value: 'promotion',   label: 'Promotion',   icon: Tag,           color: 'text-accent' },
  { value: 'alert',       label: 'Alert',       icon: AlertTriangle, color: 'text-status-pending' },
  { value: 'feature',     label: 'New Feature', icon: Star,          color: 'text-primary' },
  { value: 'info',        label: 'Info',        icon: Info,          color: 'text-primary' },
]

const TEMPLATES = [
  {
    label: 'New listings available',
    title: 'New Listings Just Added 🏠',
    body: 'Fresh properties have been listed in your area. Browse now and find your perfect home.',
    type: 'general',
  },
  {
    label: 'Booking reminder',
    title: 'Upcoming Booking Reminder',
    body: 'You have a property viewing scheduled soon. Check your bookings for details.',
    type: 'info',
  },
  {
    label: 'Maintenance notice',
    title: 'Scheduled Maintenance',
    body: 'NestIQ will undergo scheduled maintenance. Some features may be temporarily unavailable.',
    type: 'alert',
  },
  {
    label: 'Promo offer',
    title: 'Limited Time Offer 🎉',
    body: 'Enjoy reduced service fees this week only. List your property now and save.',
    type: 'promotion',
  },
  {
    label: 'Agent verification',
    title: 'Get Verified Today',
    body: 'Complete your agent verification to unlock the verified badge and gain more client trust.',
    type: 'feature',
  },
]

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtDateTime(ts) {
  if (!ts) return '—'
  try {
    const d = ts.toDate ? ts.toDate() : new Date(ts)
    return format(d, 'MMM d, yyyy · h:mm a')
  } catch { return '—' }
}

function Skeleton({ className }) {
  return <div className={clsx('animate-pulse bg-neutral-variant rounded', className)} />
}

// ─── Audience Card ────────────────────────────────────────────────────────────
function AudienceCard({ option, selected, onClick }) {
  const Icon = option.icon
  return (
    <button
      onClick={() => onClick(option.value)}
      className={clsx(
        'flex items-start gap-3 p-4 rounded-lg border-2 text-left w-full transition-all duration-150',
        selected
          ? `${option.border} ${option.bg}`
          : 'border-neutral-border hover:border-neutral-border hover:bg-neutral-variant'
      )}
    >
      <div className={clsx(
        'w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5',
        selected ? option.bg : 'bg-neutral-variant'
      )}>
        <Icon size={16} className={selected ? option.color : 'text-text-tertiary'} />
      </div>
      <div>
        <p className={clsx('text-sm font-semibold', selected ? 'text-text-primary' : 'text-text-secondary')}>
          {option.label}
        </p>
        <p className="text-xs text-text-tertiary mt-0.5">{option.description}</p>
      </div>
      {selected && (
        <CheckCircle size={16} className={clsx('ml-auto flex-shrink-0 mt-1', option.color)} />
      )}
    </button>
  )
}

// ─── User Search ──────────────────────────────────────────────────────────────
function UserSearch({ onSelect, selectedUser }) {
  const [query_, setQuery] = useState('')
  const [results, setResults] = useState([])
  const [searching, setSearching] = useState(false)
  const [open, setOpen] = useState(false)

  async function search(val) {
    setQuery(val)
    if (val.trim().length < 3) { setResults([]); setOpen(false); return }
    setSearching(true)
    try {
      // Search by email prefix
      const emailQ = query(
        collection(db, 'users'),
        where('email', '>=', val),
        where('email', '<=', val + '\uf8ff'),
        limit(5)
      )
      const snap = await getDocs(emailQ)
      setResults(snap.docs.map(d => ({ id: d.id, ...d.data() })))
      setOpen(true)
    } catch { setResults([]) }
    finally { setSearching(false) }
  }

  function select(user) {
    onSelect(user)
    setQuery(user.email || user.displayName || user.id)
    setOpen(false)
  }

  function clear() {
    onSelect(null)
    setQuery('')
    setResults([])
    setOpen(false)
  }

  return (
    <div className="relative">
      <div className="relative">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" />
        <input
          type="text"
          value={query_}
          onChange={e => search(e.target.value)}
          placeholder="Search by email or name…"
          className="search-input pl-9 pr-9 w-full"
        />
        {(query_ || selectedUser) && (
          <button onClick={clear} className="absolute right-3 top-1/2 -translate-y-1/2 text-text-tertiary hover:text-text-primary">
            <X size={14} />
          </button>
        )}
      </div>

      {/* Dropdown */}
      {open && results.length > 0 && (
        <div className="absolute z-20 w-full mt-1 bg-neutral-surface border border-neutral-border rounded-lg shadow-md overflow-hidden animate-fade-in">
          {results.map(user => (
            <button
              key={user.id}
              onClick={() => select(user)}
              className="w-full flex items-center gap-3 px-4 py-3 hover:bg-neutral-variant text-left transition-colors"
            >
              <div className="w-7 h-7 rounded-lg bg-primary-surface text-primary text-xs font-bold flex items-center justify-center flex-shrink-0">
                {(user.displayName || user.email || 'U').slice(0, 2).toUpperCase()}
              </div>
              <div className="min-w-0">
                <p className="text-sm font-medium text-text-primary truncate">{user.displayName || '—'}</p>
                <p className="text-xs text-text-tertiary truncate">{user.email}</p>
              </div>
              <span className="badge badge-neutral ml-auto flex-shrink-0">{user.role}</span>
            </button>
          ))}
        </div>
      )}

      {/* Selected user pill */}
      {selectedUser && (
        <div className="mt-2 flex items-center gap-2 px-3 py-2 bg-primary-surface rounded-lg">
          <CheckCircle size={14} className="text-primary flex-shrink-0" />
          <span className="text-sm text-primary font-medium truncate">
            {selectedUser.displayName || selectedUser.email}
          </span>
          <span className="text-xs text-primary/60 ml-auto">{selectedUser.id.slice(0, 8)}…</span>
        </div>
      )}
    </div>
  )
}

// ─── History Item ─────────────────────────────────────────────────────────────
function HistoryItem({ notif }) {
  const [expanded, setExpanded] = useState(false)
  const typeMap = {
    general:   { icon: Bell,          color: 'text-text-secondary',  bg: 'bg-neutral-variant' },
    promotion: { icon: Tag,           color: 'text-accent',          bg: 'bg-accent-surface' },
    alert:     { icon: AlertTriangle, color: 'text-status-pending',  bg: 'bg-status-pending-bg' },
    feature:   { icon: Star,          color: 'text-primary',         bg: 'bg-primary-surface' },
    info:      { icon: Info,          color: 'text-primary',         bg: 'bg-primary-surface' },
  }
  const cfg = typeMap[notif.type] ?? typeMap.general
  const Icon = cfg.icon

  const audienceLabel = {
    all:      'All Users',
    agents:   'All Agents',
    specific: notif.recipientEmail || 'Specific User',
  }[notif.audience] ?? notif.audience

  return (
    <div className="border border-neutral-border rounded-lg overflow-hidden">
      <button
        onClick={() => setExpanded(v => !v)}
        className="w-full flex items-center gap-3 px-4 py-3 hover:bg-neutral-variant transition-colors text-left"
      >
        <div className={clsx('w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0', cfg.bg)}>
          <Icon size={14} className={cfg.color} />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-text-primary truncate">{notif.title}</p>
          <p className="text-xs text-text-tertiary mt-0.5">{audienceLabel} · {fmtDateTime(notif.sentAt)}</p>
        </div>
        {expanded ? <ChevronUp size={14} className="text-text-tertiary flex-shrink-0" /> : <ChevronDown size={14} className="text-text-tertiary flex-shrink-0" />}
      </button>
      {expanded && (
        <div className="px-4 pb-4 pt-0 border-t border-neutral-divider">
          <p className="text-sm text-text-secondary leading-relaxed mt-3">{notif.body}</p>
          <div className="flex items-center gap-2 mt-3 flex-wrap">
            <span className="badge badge-neutral">{notif.type}</span>
            <span className="badge badge-primary">{audienceLabel}</span>
            {notif.sentBy && (
              <span className="text-xs text-text-tertiary">by {notif.sentBy}</span>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Main Component ───────────────────────────────────────────────────────────
export default function NotificationsPage() {
  const [audience, setAudience]       = useState('all')
  const [specificUser, setSpecific]   = useState(null)
  const [title, setTitle]             = useState('')
  const [body, setBody]               = useState('')
  const [notifType, setNotifType]     = useState('general')
  const [sending, setSending]         = useState(false)
  const [history, setHistory]         = useState([])
  const [historyLoading, setHistLoad] = useState(true)
  const [toast, setToast]             = useState(null)

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 4000)
  }

  useEffect(() => { loadHistory() }, [])

  async function loadHistory() {
    setHistLoad(true)
    try {
      const q = query(
        collection(db, 'notifications'),
        orderBy('sentAt', 'desc'),
        limit(20)
      )
      const snap = await getDocs(q)
      setHistory(snap.docs.map(d => ({ id: d.id, ...d.data() })))
    } catch (err) { console.error(err) }
    finally { setHistLoad(false) }
  }

  function applyTemplate(tpl) {
    setTitle(tpl.title)
    setBody(tpl.body)
    setNotifType(tpl.type)
  }

  const canSend = title.trim() && body.trim() && (audience !== 'specific' || specificUser)

  async function handleSend() {
    if (!canSend) return
    setSending(true)
    try {
      const payload = {
        title:        title.trim(),
        body:         body.trim(),
        type:         notifType,
        audience,
        sentAt:       serverTimestamp(),
        sentBy:       'admin',
        ...(audience === 'specific' && specificUser
          ? { recipientId: specificUser.id, recipientEmail: specificUser.email }
          : {}),
      }

      // Write to notifications collection — your FCM cloud function listens here
      await addDoc(collection(db, 'notifications'), payload)

      // Also write to notificationQueue for FCM dispatch
      await addDoc(collection(db, 'notificationQueue'), {
        ...payload,
        status: 'queued',
        queuedAt: serverTimestamp(),
      })

      showToast(`Notification sent to ${
        audience === 'all'      ? 'all users' :
        audience === 'agents'   ? 'all agents' :
        specificUser?.displayName || specificUser?.email || 'user'
      }.`)

      // Reset form
      setTitle('')
      setBody('')
      setNotifType('general')
      setSpecific(null)
      setAudience('all')
      await loadHistory()
    } catch (err) {
      console.error(err)
      showToast('Failed to send notification. Please try again.', 'error')
    } finally {
      setSending(false)
    }
  }

  const titleLen = title.length
  const bodyLen  = body.length

  return (
    <div className="space-y-6">
      <div className="page-header">
        <div>
          <h1 className="page-title">Notifications</h1>
          <p className="page-subtitle">Send push notifications to your platform users</p>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* ── Compose Panel ── */}
        <div className="xl:col-span-2 space-y-5">

          {/* Audience */}
          <div className="card p-5">
            <h2 className="text-md font-semibold text-text-primary mb-4 flex items-center gap-2">
              <Megaphone size={16} className="text-primary" />
              Audience
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              {AUDIENCE_OPTIONS.map(opt => (
                <AudienceCard
                  key={opt.value}
                  option={opt}
                  selected={audience === opt.value}
                  onClick={setAudience}
                />
              ))}
            </div>

            {/* Specific user search */}
            {audience === 'specific' && (
              <div className="mt-4 pt-4 border-t border-neutral-divider">
                <label className="block text-sm font-medium text-text-primary mb-2">
                  Search user
                </label>
                <UserSearch onSelect={setSpecific} selectedUser={specificUser} />
              </div>
            )}
          </div>

          {/* Notification type */}
          <div className="card p-5">
            <h2 className="text-md font-semibold text-text-primary mb-4 flex items-center gap-2">
              <Bell size={16} className="text-primary" />
              Type
            </h2>
            <div className="flex flex-wrap gap-2">
              {NOTIFICATION_TYPES.map(t => {
                const Icon = t.icon
                return (
                  <button
                    key={t.value}
                    onClick={() => setNotifType(t.value)}
                    className={clsx(
                      'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium border transition-all duration-150',
                      notifType === t.value
                        ? 'bg-primary text-white border-primary'
                        : 'bg-neutral-variant text-text-secondary border-neutral-border hover:border-primary/40'
                    )}
                  >
                    <Icon size={13} className={notifType === t.value ? 'text-white' : t.color} />
                    {t.label}
                  </button>
                )
              })}
            </div>
          </div>

          {/* Compose */}
          <div className="card p-5">
            <h2 className="text-md font-semibold text-text-primary mb-4 flex items-center gap-2">
              <Send size={16} className="text-primary" />
              Message
            </h2>

            {/* Title */}
            <div className="mb-4">
              <div className="flex items-center justify-between mb-1.5">
                <label className="text-sm font-medium text-text-primary">Title</label>
                <span className={clsx('text-xs', titleLen > 60 ? 'text-status-error' : 'text-text-tertiary')}>
                  {titleLen}/65
                </span>
              </div>
              <input
                type="text"
                value={title}
                onChange={e => setTitle(e.target.value.slice(0, 65))}
                placeholder="e.g. New listings available in your area"
                className="w-full bg-neutral-variant border border-neutral-border rounded px-3.5 py-2.5
                           text-base text-text-primary placeholder:text-text-tertiary
                           focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all"
              />
            </div>

            {/* Body */}
            <div className="mb-5">
              <div className="flex items-center justify-between mb-1.5">
                <label className="text-sm font-medium text-text-primary">Message</label>
                <span className={clsx('text-xs', bodyLen > 200 ? 'text-status-error' : 'text-text-tertiary')}>
                  {bodyLen}/240
                </span>
              </div>
              <textarea
                value={body}
                onChange={e => setBody(e.target.value.slice(0, 240))}
                placeholder="Write your notification message here…"
                rows={4}
                className="w-full bg-neutral-variant border border-neutral-border rounded px-3.5 py-2.5
                           text-base text-text-primary placeholder:text-text-tertiary resize-none
                           focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all"
              />
            </div>

            {/* Preview */}
            {(title || body) && (
              <div className="mb-5 p-4 bg-neutral-variant rounded-lg border border-neutral-border">
                <p className="text-xs font-semibold text-text-tertiary uppercase tracking-wider mb-2">Preview</p>
                <div className="flex items-start gap-3">
                  <div className="w-9 h-9 rounded-xl bg-primary flex items-center justify-center flex-shrink-0">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                      <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
                      <polyline points="9 22 9 12 15 12 15 22" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-text-primary">{title || 'Notification title'}</p>
                    <p className="text-xs text-text-secondary mt-0.5 leading-relaxed">{body || 'Message body…'}</p>
                    <p className="text-2xs text-text-tertiary mt-1.5">NestIQ · now</p>
                  </div>
                </div>
              </div>
            )}

            {/* Send button */}
            <button
              onClick={handleSend}
              disabled={!canSend || sending}
              className="w-full flex items-center justify-center gap-2 bg-primary hover:bg-primary-light
                         text-white font-semibold text-md rounded py-3 transition-all
                         disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {sending ? (
                <>
                  <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  Sending…
                </>
              ) : (
                <>
                  <Send size={16} />
                  Send to {
                    audience === 'all'      ? 'All Users' :
                    audience === 'agents'   ? 'All Agents' :
                    specificUser?.displayName || specificUser?.email || 'User'
                  }
                </>
              )}
            </button>

            {audience === 'specific' && !specificUser && (
              <p className="text-xs text-status-pending text-center mt-2">
                Select a user above to enable sending.
              </p>
            )}
          </div>
        </div>

        {/* ── Right Column ── */}
        <div className="space-y-5">
          {/* Templates */}
          <div className="card p-5">
            <h2 className="text-md font-semibold text-text-primary mb-4">Templates</h2>
            <div className="space-y-2">
              {TEMPLATES.map(tpl => (
                <button
                  key={tpl.label}
                  onClick={() => applyTemplate(tpl)}
                  className="w-full text-left px-3 py-2.5 rounded-lg border border-neutral-border
                             hover:bg-neutral-variant hover:border-primary/30 transition-all duration-150 group"
                >
                  <p className="text-sm font-medium text-text-primary group-hover:text-primary transition-colors">
                    {tpl.label}
                  </p>
                  <p className="text-xs text-text-tertiary mt-0.5 truncate">{tpl.title}</p>
                </button>
              ))}
            </div>
          </div>

          {/* History */}
          <div className="card p-5">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-md font-semibold text-text-primary">Recent</h2>
              <button onClick={loadHistory} className="text-text-tertiary hover:text-text-primary transition-colors">
                <Clock size={14} />
              </button>
            </div>
            <div className="space-y-2">
              {historyLoading ? (
                Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="flex gap-3 p-3 border border-neutral-border rounded-lg">
                    <Skeleton className="w-8 h-8 rounded-lg flex-shrink-0" />
                    <div className="flex-1 space-y-1.5">
                      <Skeleton className="h-4 w-3/4" />
                      <Skeleton className="h-3 w-1/2" />
                    </div>
                  </div>
                ))
              ) : history.length === 0 ? (
                <div className="empty-state py-8">
                  <Bell size={24} className="text-text-tertiary mb-2" />
                  <p className="text-sm text-text-secondary">No notifications sent yet</p>
                </div>
              ) : (
                history.map(notif => (
                  <HistoryItem key={notif.id} notif={notif} />
                ))
              )}
            </div>
          </div>
        </div>
      </div>

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