import React, { useEffect, useState, useCallback } from 'react'
import {
  collection, query, where, orderBy, limit,
  startAfter, getDocs, getCountFromServer, Timestamp
} from 'firebase/firestore'
import { db } from '../firebase/config'
import {
  CreditCard, Search, Download, ChevronLeft,
  ChevronRight, RefreshCw, X, CheckCircle,
  XCircle, Clock, AlertCircle, Phone, User,
  Calendar, Hash, Building2, Eye
} from 'lucide-react'
import { format, startOfDay, endOfDay } from 'date-fns'
import Papa from 'papaparse'
import clsx from 'clsx'

// ─── Constants ────────────────────────────────────────────────────────────────
const PAGE_SIZE = 20

const STATUS_OPTIONS = [
  { value: 'all',      label: 'All Status' },
  { value: 'completed', label: 'Completed' },
  { value: 'pending',  label: 'Pending' },
  { value: 'failed',   label: 'Failed' },
  { value: 'refunded', label: 'Refunded' },
]

const METHOD_OPTIONS = [
  { value: 'all',   label: 'All Methods' },
  { value: 'mpesa', label: 'M-Pesa' },
  { value: 'card',  label: 'Card' },
  { value: 'bank',  label: 'Bank Transfer' },
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

function fmtDateTimeRaw(ts) {
  if (!ts) return ''
  try {
    const d = ts.toDate ? ts.toDate() : new Date(ts)
    return format(d, 'yyyy-MM-dd HH:mm:ss')
  } catch { return '' }
}

function fmtKES(n) {
  if (n === undefined || n === null) return '—'
  if (n >= 1_000_000) return `KES ${(n / 1_000_000).toFixed(2)}M`
  if (n >= 1_000)     return `KES ${(n / 1_000).toFixed(2)}K`
  return `KES ${n.toFixed(2)}`
}

function Skeleton({ className }) {
  return <div className={clsx('animate-pulse bg-neutral-variant rounded', className)} />
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
function StatusBadge({ status }) {
  const map = {
    completed: { cls: 'badge-active',   icon: CheckCircle,  label: 'Completed' },
    pending:   { cls: 'badge-pending',  icon: Clock,        label: 'Pending' },
    failed:    { cls: 'badge-error',    icon: XCircle,      label: 'Failed' },
    refunded:  { cls: 'badge-neutral',  icon: AlertCircle,  label: 'Refunded' },
  }
  const cfg = map[status] ?? { cls: 'badge-neutral', icon: Clock, label: status ?? '—' }
  const Icon = cfg.icon
  return (
    <span className={clsx('badge', cfg.cls)}>
      <Icon size={9} />{cfg.label}
    </span>
  )
}

// ─── Method Badge ─────────────────────────────────────────────────────────────
function MethodBadge({ method }) {
  const map = {
    mpesa: { cls: 'bg-green-50 text-green-700',   label: 'M-Pesa' },
    card:  { cls: 'bg-primary-surface text-primary', label: 'Card' },
    bank:  { cls: 'bg-neutral-variant text-text-secondary', label: 'Bank' },
  }
  const cfg = map[method?.toLowerCase()] ?? { cls: 'badge-neutral', label: method || '—' }
  return (
    <span className={clsx('badge', cfg.cls)}>{cfg.label}</span>
  )
}

// ─── Transaction Drawer ───────────────────────────────────────────────────────
function TransactionDrawer({ tx, onClose }) {
  if (!tx) return null

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/25 animate-fade-in" onClick={onClose} />
      <div className="relative w-full max-w-md bg-neutral-surface border-l border-neutral-border h-full flex flex-col shadow-lg">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-neutral-border sticky top-0 bg-neutral-surface z-10">
          <div>
            <h3 className="text-md font-semibold text-text-primary">Transaction Detail</h3>
            <p className="text-xs text-text-tertiary mt-0.5 font-mono">#{tx.id.slice(0, 12).toUpperCase()}</p>
          </div>
          <button onClick={onClose} className="text-text-tertiary hover:text-text-primary">
            <X size={18} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-5 space-y-5">
          {/* Amount hero */}
          <div className={clsx(
            'rounded-lg p-5 flex items-center justify-between',
            tx.status === 'completed' ? 'bg-status-active-bg' :
            tx.status === 'failed'    ? 'bg-status-error-bg' :
            'bg-neutral-variant'
          )}>
            <div>
              <p className="text-xs text-text-tertiary mb-1">Amount</p>
              <p className="text-3xl font-bold text-text-primary font-display">
                {fmtKES(tx.amount)}
              </p>
            </div>
            <div className="text-right space-y-1">
              <StatusBadge status={tx.status} />
              <div><MethodBadge method={tx.method} /></div>
            </div>
          </div>

          {/* Details grid */}
          {[
            { label: 'Transaction ID',  value: tx.id,                         icon: Hash,       mono: true },
            { label: 'Reference',       value: tx.reference || tx.mpesaRef || '—', icon: Hash,  mono: true },
            { label: 'Payer',           value: tx.payerName || '—',           icon: User },
            { label: 'Payer Phone',     value: tx.payerPhone || '—',          icon: Phone },
            { label: 'Booking ID',      value: tx.bookingId || '—',           icon: Calendar,   mono: true },
            { label: 'Listing',         value: tx.propertyTitle || tx.listingId || '—', icon: Building2 },
            { label: 'Date',            value: fmtDateTime(tx.createdAt),     icon: Calendar },
            { label: 'Completed At',    value: fmtDateTime(tx.completedAt),   icon: CheckCircle },
          ].map(({ label, value, icon: Icon, mono }) => (
            <div key={label} className="flex items-center justify-between py-2.5 border-b border-neutral-divider last:border-0">
              <div className="flex items-center gap-2 text-text-secondary">
                <Icon size={13} />
                <span className="text-sm">{label}</span>
              </div>
              <span className={clsx(
                'text-sm font-medium text-right max-w-[220px] truncate',
                mono ? 'font-mono text-xs text-text-tertiary' : 'text-text-primary'
              )}>
                {value}
              </span>
            </div>
          ))}

          {/* Failure reason */}
          {tx.status === 'failed' && tx.failureReason && (
            <div className="bg-status-error-bg border border-red-100 rounded-lg p-4">
              <p className="text-xs font-semibold text-status-error uppercase tracking-wider mb-1">Failure Reason</p>
              <p className="text-sm text-status-error">{tx.failureReason}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ─── Summary Bar ──────────────────────────────────────────────────────────────
function SummaryBar({ transactions }) {
  const completed = transactions.filter(t => t.status === 'completed')
  const failed    = transactions.filter(t => t.status === 'failed')
  const total     = completed.reduce((s, t) => s + (t.amount || 0), 0)

  return (
    <div className="grid grid-cols-3 gap-3">
      {[
        { label: 'Revenue (this page)', value: fmtKES(total),        cls: 'text-status-active' },
        { label: 'Completed',           value: completed.length,      cls: 'text-text-primary' },
        { label: 'Failed',              value: failed.length,         cls: 'text-status-error' },
      ].map(s => (
        <div key={s.label} className="stat-card py-4">
          <p className={clsx('text-xl font-bold font-display', s.cls)}>{s.value}</p>
          <p className="text-xs text-text-tertiary mt-0.5">{s.label}</p>
        </div>
      ))}
    </div>
  )
}

// ─── Main Component ───────────────────────────────────────────────────────────
export default function TransactionsPage() {
  const [transactions, setTransactions] = useState([])
  const [loading, setLoading]           = useState(true)
  const [total, setTotal]               = useState(0)
  const [search, setSearch]             = useState('')
  const [statusFilter, setStatus]       = useState('all')
  const [methodFilter, setMethod]       = useState('all')
  const [dateFrom, setDateFrom]         = useState('')
  const [dateTo, setDateTo]             = useState('')
  const [page, setPage]                 = useState(0)
  const [cursors, setCursors]           = useState([null])
  const [selected, setSelected]         = useState(null)
  const [exporting, setExporting]       = useState(false)
  const [toast, setToast]               = useState(null)

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3000)
  }

  const buildConstraints = useCallback(() => {
    const c = []
    if (statusFilter !== 'all') c.push(where('status',  '==', statusFilter))
    if (methodFilter !== 'all') c.push(where('method',  '==', methodFilter))
    if (dateFrom) c.push(where('createdAt', '>=', Timestamp.fromDate(startOfDay(new Date(dateFrom)))))
    if (dateTo)   c.push(where('createdAt', '<=', Timestamp.fromDate(endOfDay(new Date(dateTo)))))
    c.push(orderBy('createdAt', 'desc'))
    return c
  }, [statusFilter, methodFilter, dateFrom, dateTo])

  useEffect(() => {
    const loadCount = async () => {
      try {
        const q = query(collection(db, 'transactions'), ...buildConstraints())
        const snap = await getCountFromServer(q)
        setTotal(snap.data().count)
      } catch { setTotal(0) }
    }
    loadCount()
  }, [buildConstraints])

  useEffect(() => { loadPage() }, [page, statusFilter, methodFilter, dateFrom, dateTo])
  useEffect(() => { setPage(0); setCursors([null]) }, [statusFilter, methodFilter, dateFrom, dateTo])

  async function loadPage() {
    setLoading(true)
    try {
      const constraints = buildConstraints()
      const cursor = cursors[page]
      const q = cursor
        ? query(collection(db, 'transactions'), ...constraints, startAfter(cursor), limit(PAGE_SIZE))
        : query(collection(db, 'transactions'), ...constraints, limit(PAGE_SIZE))
      const snap = await getDocs(q)
      setTransactions(snap.docs.map(d => ({ id: d.id, ...d.data() })))
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

  // ─── CSV Export ────────────────────────────────────────────────────────────
  async function handleExport() {
    setExporting(true)
    try {
      // Fetch up to 5000 rows matching current filters (no pagination limit)
      const constraints = buildConstraints()
      const q = query(collection(db, 'transactions'), ...constraints, limit(5000))
      const snap = await getDocs(q)
      const rows = snap.docs.map(d => {
        const t = d.data()
        return {
          'Transaction ID': d.id,
          'Reference':      t.reference || t.mpesaRef || '',
          'Date':           fmtDateTimeRaw(t.createdAt),
          'Payer Name':     t.payerName || '',
          'Payer Phone':    t.payerPhone || '',
          'Amount (KES)':   t.amount ?? '',
          'Method':         t.method || '',
          'Status':         t.status || '',
          'Booking ID':     t.bookingId || '',
          'Listing Title':  t.propertyTitle || '',
          'Failure Reason': t.failureReason || '',
          'Completed At':   fmtDateTimeRaw(t.completedAt),
        }
      })
      const csv = Papa.unparse(rows)
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
      const url  = URL.createObjectURL(blob)
      const a    = document.createElement('a')
      a.href     = url
      a.download = `nestiq-transactions-${format(new Date(), 'yyyy-MM-dd')}.csv`
      a.click()
      URL.revokeObjectURL(url)
      showToast(`${rows.length} transactions exported.`)
    } catch (err) {
      console.error(err)
      showToast('Export failed. Please try again.', 'error')
    } finally {
      setExporting(false)
    }
  }

  const filtered = search.trim()
    ? transactions.filter(t =>
        [t.id, t.reference, t.mpesaRef, t.payerName, t.payerPhone, t.propertyTitle]
          .some(v => v?.toLowerCase().includes(search.toLowerCase()))
      )
    : transactions

  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div className="space-y-5">
      <div className="page-header">
        <div>
          <h1 className="page-title">Transactions</h1>
          <p className="page-subtitle">{total.toLocaleString()} payment records</p>
        </div>
        <button
          onClick={handleExport}
          disabled={exporting}
          className="flex items-center gap-2 bg-primary hover:bg-primary-light text-white
                     text-sm font-semibold px-4 py-2 rounded transition-colors disabled:opacity-60"
        >
          {exporting
            ? <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            : <Download size={15} />}
          Export CSV
        </button>
      </div>

      {/* Summary */}
      {!loading && <SummaryBar transactions={filtered} />}

      {/* Filters */}
      <div className="filter-bar">
        <div className="relative flex-1 min-w-48 max-w-xs">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" />
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search reference, payer…"
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
        <select value={methodFilter} onChange={e => setMethod(e.target.value)} className="filter-select">
          {METHOD_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <input type="date" value={dateFrom} onChange={e => setDateFrom(e.target.value)} className="filter-select text-sm" title="From" />
        <input type="date" value={dateTo}   onChange={e => setDateTo(e.target.value)}   className="filter-select text-sm" title="To" />
        {(dateFrom || dateTo) && (
          <button onClick={() => { setDateFrom(''); setDateTo('') }} className="btn-ghost border border-neutral-border rounded px-2 py-2 text-xs gap-1">
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
                <th>Reference</th>
                <th>Payer</th>
                <th>Property</th>
                <th>Method</th>
                <th>Amount</th>
                <th>Date</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i}>
                    {[120, 160, 150, 70, 90, 100, 80, 40].map((w, j) => (
                      <td key={j}><Skeleton className="h-4" style={{ width: w }} /></td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <CreditCard size={28} className="text-text-tertiary mb-2" />
                      <p className="text-sm text-text-secondary">No transactions found</p>
                      <p className="text-xs text-text-tertiary mt-1">Try adjusting your filters.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(tx => (
                  <tr key={tx.id}>
                    {/* Reference */}
                    <td>
                      <span className="font-mono text-xs text-text-secondary">
                        {(tx.reference || tx.mpesaRef || tx.id)?.slice(0, 14)}…
                      </span>
                    </td>
                    {/* Payer */}
                    <td>
                      <div>
                        <p className="text-sm font-medium text-text-primary">{tx.payerName || '—'}</p>
                        <p className="text-xs text-text-tertiary">{tx.payerPhone || ''}</p>
                      </div>
                    </td>
                    {/* Property */}
                    <td>
                      <p className="text-sm text-text-secondary truncate max-w-[140px]">
                        {tx.propertyTitle || tx.listingId?.slice(0, 10) || '—'}
                      </p>
                    </td>
                    {/* Method */}
                    <td><MethodBadge method={tx.method} /></td>
                    {/* Amount */}
                    <td>
                      <span className={clsx(
                        'text-sm font-bold',
                        tx.status === 'failed' ? 'text-text-tertiary line-through' : 'text-text-primary'
                      )}>
                        {fmtKES(tx.amount)}
                      </span>
                    </td>
                    {/* Date */}
                    <td><span className="text-sm text-text-secondary">{fmtDate(tx.createdAt)}</span></td>
                    {/* Status */}
                    <td><StatusBadge status={tx.status} /></td>
                    {/* View */}
                    <td>
                      <button onClick={() => setSelected(tx)} className="btn-ghost px-2 py-1.5 rounded">
                        <Eye size={14} />
                      </button>
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

      {selected && <TransactionDrawer tx={selected} onClose={() => setSelected(null)} />}

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