import React, { useEffect, useState, useCallback } from 'react'
import {
  collection, query, where, orderBy, limit,
  startAfter, getDocs, doc, updateDoc, deleteDoc,
  serverTimestamp, getCountFromServer, Timestamp
} from 'firebase/firestore'
import { db } from '../firebase/config'
import {
  CalendarDays, Search, CheckCircle, XCircle,
  ChevronLeft, ChevronRight, RefreshCw, X,
  Clock, MapPin, User, Building2, Phone,
  Mail, Eye, AlertTriangle, Ban, Trash2
} from 'lucide-react'
import { format, startOfDay, endOfDay } from 'date-fns'
import clsx from 'clsx'

// ─── Constants ────────────────────────────────────────────────────────────────
const PAGE_SIZE = 20

const STATUS_OPTIONS = [
  { value: 'all',       label: 'All Bookings' },
  { value: 'pending',   label: 'Pending' },
  { value: 'confirmed', label: 'Confirmed' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled', label: 'Cancelled' },
]

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtDate(ts) {
  if (!ts) return '—'
  try {
    const d = ts.toDate ? ts.toDate() : new Date(ts)
    return format(d, 'MMM d, yyyy')
  } catch { return '—' }
}

function fmtDateTime(ts) {
  if (!ts) return '—'
  try {
    const d = ts.toDate ? ts.toDate() : new Date(ts)
    return format(d, 'MMM d, yyyy · h:mm a')
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

// ─── Status Badge ─────────────────────────────────────────────────────────────
function StatusBadge({ status }) {
  const map = {
    pending:   { cls: 'badge-pending',  icon: Clock,        label: 'Pending' },
    confirmed: { cls: 'badge-primary',  icon: CheckCircle,  label: 'Confirmed' },
    completed: { cls: 'badge-active',   icon: CheckCircle,  label: 'Completed' },
    cancelled: { cls: 'badge-error',    icon: Ban,          label: 'Cancelled' },
  }
  const cfg = map[status] ?? { cls: 'badge-neutral', icon: Clock, label: status }
  const Icon = cfg.icon
  return (
    <span className={clsx('badge', cfg.cls)}>
      <Icon size={9} />{cfg.label}
    </span>
  )
}

// ─── Booking Drawer ───────────────────────────────────────────────────────────
function BookingDrawer({ booking, onClose, onAction, actionLoading }) {
  if (!booking) return null

  const sections = [
    {
      title: 'Property',
      fields: [
        { label: 'Title',    value: booking.propertyTitle || booking.listingId || '—', icon: Building2 },
        { label: 'Location', value: booking.propertyLocation || '—',                   icon: MapPin },
        { label: 'Price',    value: fmtKES(booking.amount),                            icon: null },
      ],
    },
    {
      title: 'Guest',
      fields: [
        { label: 'Name',  value: booking.guestName || '—',  icon: User },
        { label: 'Email', value: booking.guestEmail || '—', icon: Mail },
        { label: 'Phone', value: booking.guestPhone || '—', icon: Phone },
      ],
    },
    {
      title: 'Booking Details',
      fields: [
        { label: 'Check-in',   value: fmtDate(booking.checkIn),       icon: CalendarDays },
        { label: 'Check-out',  value: fmtDate(booking.checkOut),      icon: CalendarDays },
        { label: 'Guests',     value: booking.guestCount ?? '—',      icon: User },
        { label: 'Created',    value: fmtDateTime(booking.createdAt), icon: Clock },
        { label: 'Agent ID',   value: booking.agentId
            ? booking.agentId.slice(0, 12) + '…' : '—',              icon: null },
        { label: 'Booking ID', value: booking.id.slice(0, 12) + '…', icon: null },
      ],
    },
  ]

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/25 animate-fade-in" onClick={onClose} />
      <div className="relative w-full max-w-md bg-neutral-surface border-l border-neutral-border h-full flex flex-col shadow-lg">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-neutral-border sticky top-0 bg-neutral-surface z-10">
          <div>
            <h3 className="text-md font-semibold text-text-primary">Booking Detail</h3>
            <p className="text-xs text-text-tertiary mt-0.5">#{booking.id.slice(0, 8).toUpperCase()}</p>
          </div>
          <button onClick={onClose} className="text-text-tertiary hover:text-text-primary">
            <X size={18} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-5 space-y-5">
          {/* Status + amount hero */}
          <div className="flex items-center justify-between p-4 bg-neutral-variant rounded-lg">
            <div>
              <p className="text-xs text-text-tertiary mb-1">Amount</p>
              <p className="text-2xl font-bold text-text-primary font-display">{fmtKES(booking.amount)}</p>
            </div>
            <StatusBadge status={booking.status} />
          </div>

          {/* Sections */}
          {sections.map(section => (
            <div key={section.title}>
              <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-2">
                {section.title}
              </p>
              <div className="space-y-0">
                {section.fields.map(({ label, value, icon: Icon }) => (
                  <div key={label} className="flex items-center justify-between py-2.5 border-b border-neutral-divider last:border-0">
                    <div className="flex items-center gap-2 text-text-secondary">
                      {Icon && <Icon size={13} />}
                      <span className="text-sm">{label}</span>
                    </div>
                    <span className="text-sm font-medium text-text-primary text-right max-w-[200px] truncate font-mono text-xs">
                      {value}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          ))}

          {/* Notes */}
          {booking.notes && (
            <div>
              <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-2">Notes</p>
              <p className="text-sm text-text-secondary leading-relaxed bg-neutral-variant rounded-lg p-3">
                {booking.notes}
              </p>
            </div>
          )}

          {/* Actions */}
          <div className="space-y-2 pt-1">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">Actions</p>
            {booking.status === 'pending' && (
              <>
                <button
                  onClick={() => onAction('confirm', booking)}
                  disabled={actionLoading}
                  className="w-full btn-success border border-green-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
                >
                  <CheckCircle size={15} /> Confirm Booking
                </button>
                <button
                  onClick={() => onAction('cancel', booking)}
                  disabled={actionLoading}
                  className="w-full btn-danger border border-red-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
                >
                  <XCircle size={15} /> Cancel Booking
                </button>
              </>
            )}
            {booking.status === 'confirmed' && (
              <>
                <button
                  onClick={() => onAction('complete', booking)}
                  disabled={actionLoading}
                  className="w-full btn-accent border border-green-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
                >
                  <CheckCircle size={15} /> Mark as Completed
                </button>
                <button
                  onClick={() => onAction('cancel', booking)}
                  disabled={actionLoading}
                  className="w-full btn-danger border border-red-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
                >
                  <XCircle size={15} /> Cancel Booking
                </button>
              </>
            )}
            {(booking.status === 'completed' || booking.status === 'cancelled') && (
              <p className="text-xs text-text-tertiary text-center py-2">
                This booking is {booking.status} and cannot be modified.
              </p>
            )}
            {booking.status === 'cancelled' && (
              <button
                onClick={() => onAction('delete', booking)}
                disabled={actionLoading}
                className="w-full btn-danger border border-red-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
              >
                <Trash2 size={15} /> Delete Permanently
              </button>
            )}
          </div>
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
          <button onClick={onClose} className="text-text-tertiary hover:text-text-primary"><X size={18} /></button>
        </div>
        <div className="p-5">
          <div className="flex items-start gap-3 mb-5">
            <div className="w-9 h-9 rounded-lg bg-status-pending-bg flex items-center justify-center flex-shrink-0">
              <AlertTriangle size={16} className="text-status-pending" />
            </div>
            <p className="text-sm text-text-secondary leading-relaxed">{message}</p>
          </div>
          <div className="flex gap-3">
            <button onClick={onClose} className="flex-1 btn-ghost border border-neutral-border rounded py-2">Cancel</button>
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
export default function BookingsPage() {
  const [bookings, setBookings]       = useState([])
  const [loading, setLoading]         = useState(true)
  const [total, setTotal]             = useState(0)
  const [search, setSearch]           = useState('')
  const [statusFilter, setStatus]     = useState('all')
  const [dateFrom, setDateFrom]       = useState('')
  const [dateTo, setDateTo]           = useState('')
  const [agentFilter, setAgentFilter] = useState('')
  const [page, setPage]               = useState(0)
  const [cursors, setCursors]         = useState([null])
  const [selected, setSelected]       = useState(null)
  const [confirmModal, setConfirm]    = useState(null)
  const [actionLoading, setActLoading]= useState(false)
  const [toast, setToast]             = useState(null)

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3000)
  }

  const buildConstraints = useCallback(() => {
    const c = []
    if (statusFilter !== 'all') c.push(where('status', '==', statusFilter))
    if (agentFilter.trim())     c.push(where('agentId', '==', agentFilter.trim()))
    if (dateFrom) {
      c.push(where('createdAt', '>=', Timestamp.fromDate(startOfDay(new Date(dateFrom)))))
    }
    if (dateTo) {
      c.push(where('createdAt', '<=', Timestamp.fromDate(endOfDay(new Date(dateTo)))))
    }
    c.push(orderBy('createdAt', 'desc'))
    return c
  }, [statusFilter, agentFilter, dateFrom, dateTo])

  useEffect(() => {
    const loadCount = async () => {
      try {
        const q = query(collection(db, 'bookings'), ...buildConstraints())
        const snap = await getCountFromServer(q)
        setTotal(snap.data().count)
      } catch { setTotal(0) }
    }
    loadCount()
  }, [buildConstraints])

  useEffect(() => { loadPage() }, [page, statusFilter, agentFilter, dateFrom, dateTo])
  useEffect(() => { setPage(0); setCursors([null]) }, [statusFilter, agentFilter, dateFrom, dateTo])

  async function loadPage() {
    setLoading(true)
    try {
      const constraints = buildConstraints()
      const cursor = cursors[page]
      const q = cursor
        ? query(collection(db, 'bookings'), ...constraints, startAfter(cursor), limit(PAGE_SIZE))
        : query(collection(db, 'bookings'), ...constraints, limit(PAGE_SIZE))
      const snap = await getDocs(q)
      setBookings(snap.docs.map(d => ({ id: d.id, ...d.data() })))
      if (snap.docs.length === PAGE_SIZE) {
        setCursors(prev => {
          const next = [...prev]
          next[page + 1] = snap.docs[snap.docs.length - 1]
          return next
        })
      }
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  const ACTION_MAP = {
    confirm:  { title: 'Confirm Booking',   message: 'Confirm this booking? The guest will be notified.',                             confirmLabel: 'Confirm',        confirmClass: 'bg-status-active text-white' },
    complete: { title: 'Mark as Completed', message: 'Mark this booking as completed?',                                               confirmLabel: 'Complete',       confirmClass: 'bg-accent text-white' },
    cancel:   { title: 'Cancel Booking',    message: 'Cancel this booking? This action cannot be undone.',                            confirmLabel: 'Cancel',         confirmClass: 'bg-status-error text-white' },
    delete:   { title: 'Delete Booking',    message: 'Permanently delete this cancelled booking? This cannot be undone.',             confirmLabel: 'Delete Forever', confirmClass: 'bg-status-error text-white' },
  }

  function handleAction(action, booking) {
    setConfirm({ action, booking })
  }

  async function executeAction() {
    if (!confirmModal) return
    const { action, booking } = confirmModal
    setActLoading(true)
    const ref = doc(db, 'bookings', booking.id)
    try {
      const updates = {
        confirm:  { status: 'confirmed', confirmedAt: serverTimestamp() },
        complete: { status: 'completed', completedAt: serverTimestamp() },
        cancel:   { status: 'cancelled', cancelledAt: serverTimestamp() },
      }[action]
      if (action === 'delete') {
        await deleteDoc(ref)
        showToast('Booking permanently deleted.')
      } else {
        await updateDoc(ref, updates)
        showToast(`Booking ${action}ed successfully.`)
      }
      setConfirm(null)
      setSelected(null)
      await loadPage()
    } catch (err) {
      console.error(err)
      showToast('Action failed. Please try again.', 'error')
    } finally { setActLoading(false) }
  }

  const filtered = search.trim()
    ? bookings.filter(b =>
        [b.guestName, b.guestEmail, b.propertyTitle, b.id, b.agentId]
          .some(v => v?.toLowerCase().includes(search.toLowerCase()))
      )
    : bookings

  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h1 className="page-title">Bookings</h1>
          <p className="page-subtitle">{total.toLocaleString()} total bookings</p>
        </div>
      </div>

      {/* Filters */}
      <div className="filter-bar">
        <div className="relative flex-1 min-w-48 max-w-xs">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" />
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search guest, property…"
            className="search-input pl-9"
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-text-tertiary hover:text-text-primary">
              <X size={14} />
            </button>
          )}
        </div>
        <select value={statusFilter} onChange={e => setStatus(e.target.value)} className="filter-select">
          {STATUS_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <input
          type="date"
          value={dateFrom}
          onChange={e => setDateFrom(e.target.value)}
          className="filter-select text-sm"
          title="From date"
        />
        <input
          type="date"
          value={dateTo}
          onChange={e => setDateTo(e.target.value)}
          className="filter-select text-sm"
          title="To date"
        />
        <input
          type="text"
          value={agentFilter}
          onChange={e => setAgentFilter(e.target.value)}
          placeholder="Agent ID…"
          className="filter-select w-32 text-sm placeholder:text-text-tertiary"
        />
        {(dateFrom || dateTo || agentFilter) && (
          <button
            onClick={() => { setDateFrom(''); setDateTo(''); setAgentFilter('') }}
            className="btn-ghost border border-neutral-border rounded px-2 py-2 text-xs gap-1"
          >
            <X size={12} /> Clear
          </button>
        )}
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
                <th>Guest</th>
                <th>Property</th>
                <th>Check-in</th>
                <th>Check-out</th>
                <th>Amount</th>
                <th>Booked</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i}>
                    {[180, 160, 90, 90, 80, 90, 80, 80].map((w, j) => (
                      <td key={j}><Skeleton className="h-4" style={{ width: w }} /></td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <CalendarDays size={28} className="text-text-tertiary mb-2" />
                      <p className="text-sm text-text-secondary">No bookings found</p>
                      <p className="text-xs text-text-tertiary mt-1">Try adjusting your filters.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(booking => (
                  <tr key={booking.id}>
                    <td>
                      <div>
                        <p className="text-sm font-semibold text-text-primary">{booking.guestName || '—'}</p>
                        <p className="text-xs text-text-tertiary">{booking.guestEmail || '—'}</p>
                      </div>
                    </td>
                    <td>
                      <p className="text-sm text-text-primary truncate max-w-[150px]">
                        {booking.propertyTitle || booking.listingId?.slice(0,10) || '—'}
                      </p>
                    </td>
                    <td><span className="text-sm text-text-secondary">{fmtDate(booking.checkIn)}</span></td>
                    <td><span className="text-sm text-text-secondary">{fmtDate(booking.checkOut)}</span></td>
                    <td><span className="text-sm font-semibold text-text-primary">{fmtKES(booking.amount)}</span></td>
                    <td><span className="text-sm text-text-secondary">{fmtDate(booking.createdAt)}</span></td>
                    <td><StatusBadge status={booking.status} /></td>
                    <td>
                      <div className="flex items-center gap-1.5">
                        <button onClick={() => setSelected(booking)} className="btn-ghost px-2 py-1.5 rounded" title="View">
                          <Eye size={14} />
                        </button>
                        {booking.status === 'pending' && (
                          <>
                            <button onClick={() => handleAction('confirm', booking)} className="btn-success" disabled={actionLoading}>
                              <CheckCircle size={13} />
                            </button>
                            <button onClick={() => handleAction('cancel', booking)} className="btn-danger" disabled={actionLoading}>
                              <XCircle size={13} />
                            </button>
                          </>
                        )}
                        {booking.status === 'cancelled' && (
                          <button
                            onClick={() => handleAction('delete', booking)}
                            className="btn-danger"
                            title="Delete booking"
                            disabled={actionLoading}
                          >
                            <Trash2 size={13} />
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

        {!loading && total > PAGE_SIZE && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-neutral-border">
            <p className="text-xs text-text-tertiary">
              Showing {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, total)} of {total.toLocaleString()}
            </p>
            <div className="flex items-center gap-2">
              <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0} className="btn-ghost border border-neutral-border rounded px-2 py-1.5 disabled:opacity-40">
                <ChevronLeft size={15} />
              </button>
              <span className="text-xs text-text-secondary px-1">{page + 1} / {totalPages}</span>
              <button onClick={() => setPage(p => p + 1)} disabled={page >= totalPages - 1} className="btn-ghost border border-neutral-border rounded px-2 py-1.5 disabled:opacity-40">
                <ChevronRight size={15} />
              </button>
            </div>
          </div>
        )}
      </div>

      {selected && (
        <BookingDrawer booking={selected} onClose={() => setSelected(null)} onAction={handleAction} actionLoading={actionLoading} />
      )}

      {confirmModal && (() => {
        const cfg = ACTION_MAP[confirmModal.action]
        return (
          <ConfirmModal
            title={cfg.title} message={cfg.message} confirmLabel={cfg.confirmLabel}
            confirmClass={cfg.confirmClass} onConfirm={executeAction}
            onClose={() => setConfirm(null)} loading={actionLoading}
          />
        )
      })()}

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