import React, { useEffect, useState, useCallback } from 'react'
import {
  collection, query, where, orderBy, limit,
  startAfter, getDocs, doc, updateDoc,
  serverTimestamp, getCountFromServer
} from 'firebase/firestore'
import { db } from '../firebase/config'
import {
  Building2, Search, CheckCircle, XCircle, Star,
  Ban, Eye, ChevronLeft, ChevronRight, Filter,
  MapPin, BedDouble, Bath, Maximize2, RefreshCw,
  MoreHorizontal, X
} from 'lucide-react'
import { format } from 'date-fns'
import clsx from 'clsx'

// ─── Constants ────────────────────────────────────────────────────────────────
const PAGE_SIZE = 15

const STATUS_OPTIONS = [
  { value: 'all',       label: 'All Listings' },
  { value: 'pending',   label: 'Pending Review' },
  { value: 'approved',  label: 'Approved' },
  { value: 'suspended', label: 'Suspended' },
  { value: 'featured',  label: 'Featured' },
  { value: 'sold',      label: 'Sold' },
  { value: 'rented',    label: 'Rented' },
]

const TYPE_OPTIONS = [
  { value: 'all',        label: 'All Types' },
  { value: 'apartment',  label: 'Apartment' },
  { value: 'house',      label: 'House' },
  { value: 'land',       label: 'Land' },
  { value: 'commercial', label: 'Commercial' },
  { value: 'office',     label: 'Office' },
]

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtKES(n) {
  if (!n) return '—'
  if (n >= 1_000_000) return `KES ${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `KES ${(n / 1_000).toFixed(0)}K`
  return `KES ${n}`
}

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

// ─── Status Badge ─────────────────────────────────────────────────────────────
function StatusBadge({ listing }) {
  if (listing.status === 'sold')      return <span className="badge badge-error"><XCircle size={9} />Sold</span>
  if (listing.status === 'rented')    return <span className="badge" style={{background:'#FFF3E0',color:'#E64A19'}}><Ban size={9} />Rented</span>
  if (listing.isFeatured)             return <span className="badge badge-primary"><Star size={9} />Featured</span>
  if (listing.status === 'suspended') return <span className="badge badge-neutral"><Ban size={9} />Suspended</span>
  if (listing.isApproved)             return <span className="badge badge-active"><CheckCircle size={9} />Approved</span>
  return <span className="badge badge-pending">Pending</span>
}

// ─── Reject Modal ─────────────────────────────────────────────────────────────
function RejectModal({ listing, onClose, onConfirm, loading }) {
  const [reason, setReason] = useState('')
  const REASONS = [
    'Incomplete or inaccurate information',
    'Low quality or misleading photos',
    'Pricing inconsistency',
    'Duplicate listing',
    'Violates platform policy',
    'Other',
  ]
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/30 animate-fade-in">
      <div className="bg-neutral-surface rounded-lg border border-neutral-border w-full max-w-md shadow-lg animate-slide-up">
        <div className="flex items-center justify-between p-5 border-b border-neutral-border">
          <h3 className="text-md font-semibold text-text-primary">Reject Listing</h3>
          <button onClick={onClose} className="text-text-tertiary hover:text-text-primary">
            <X size={18} />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <div>
            <p className="text-sm text-text-secondary mb-1">
              Rejecting: <span className="font-medium text-text-primary">{listing?.title || 'Listing'}</span>
            </p>
            <p className="text-xs text-text-tertiary">The agent will be notified with the reason.</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-text-primary mb-2">Reason</label>
            <div className="space-y-2">
              {REASONS.map(r => (
                <label key={r} className="flex items-center gap-2.5 cursor-pointer group">
                  <input
                    type="radio"
                    name="reason"
                    value={r}
                    checked={reason === r}
                    onChange={() => setReason(r)}
                    className="accent-primary"
                  />
                  <span className="text-sm text-text-primary group-hover:text-primary transition-colors">{r}</span>
                </label>
              ))}
            </div>
          </div>
        </div>
        <div className="flex gap-3 p-5 pt-0">
          <button onClick={onClose} className="flex-1 btn-ghost border border-neutral-border rounded py-2">
            Cancel
          </button>
          <button
            onClick={() => onConfirm(reason)}
            disabled={!reason || loading}
            className="flex-1 btn-danger border border-red-100 rounded py-2 disabled:opacity-50"
          >
            {loading ? 'Rejecting…' : 'Reject Listing'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── Detail Drawer ────────────────────────────────────────────────────────────
function ListingDrawer({ listing, onClose, onAction, actionLoading }) {
  if (!listing) return null
  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/25 animate-fade-in" onClick={onClose} />
      <div className="relative w-full max-w-md bg-neutral-surface border-l border-neutral-border
                      h-full overflow-y-auto shadow-lg animate-slide-in-right flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-neutral-border sticky top-0 bg-neutral-surface z-10">
          <h3 className="text-md font-semibold text-text-primary">Listing Detail</h3>
          <button onClick={onClose} className="text-text-tertiary hover:text-text-primary">
            <X size={18} />
          </button>
        </div>

        {/* Image */}
        {listing.imageUrls?.[0] ? (
          <img
            src={listing.imageUrls[0]}
            alt={listing.title}
            className="w-full h-48 object-cover"
          />
        ) : (
          <div className="w-full h-48 bg-neutral-variant flex items-center justify-center">
            <Building2 size={32} className="text-text-tertiary" />
          </div>
        )}

        <div className="p-5 flex-1 space-y-5">
          {/* Title & status */}
          <div>
            <div className="flex items-start justify-between gap-3 mb-1">
              <h4 className="text-lg font-semibold text-text-primary leading-snug">{listing.title || '—'}</h4>
              <StatusBadge listing={listing} />
            </div>
            <div className="flex items-center gap-1 text-sm text-text-secondary">
              <MapPin size={13} />
              <span>{typeof listing.location === 'object' ? [listing.location?.city, listing.location?.country].filter(Boolean).join(', ') || '—' : listing.location || '—'}</span>
            </div>
          </div>

          {/* Price & type */}
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: 'Price',          value: fmtKES(listing.price) },
              { label: 'Type',           value: listing.type || '—' },
              { label: 'Bedrooms',       value: listing.bedrooms ?? '—' },
              { label: 'Bathrooms',      value: listing.bathrooms ?? '—' },
              { label: 'Size',           value: listing.areaSqFt ? `${listing.areaSqFt} sqft` : '—' },
              { label: 'Listed',         value: fmtDate(listing.createdAt) },
              { label: 'Agent ID',       value: listing.agentId || '—' },
              { label: 'Views',          value: listing.viewCount ?? 0 },
            ].map(({ label, value }) => (
              <div key={label} className="bg-neutral-variant rounded-lg p-3">
                <p className="text-xs text-text-tertiary mb-0.5">{label}</p>
                <p className="text-sm font-semibold text-text-primary truncate">{value}</p>
              </div>
            ))}
          </div>

          {/* Description */}
          {listing.description && (
            <div>
              <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-2">Description</p>
              <p className="text-sm text-text-secondary leading-relaxed line-clamp-4">{listing.description}</p>
            </div>
          )}

          {/* Actions */}
          <div className="space-y-2 pt-2">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">Actions</p>

            {/* Sold / Rented — no further admin actions available */}
            {(listing.status === 'sold' || listing.status === 'rented') && (
              <div className="px-3 py-3 rounded-lg bg-neutral-variant text-center">
                <p className="text-sm font-semibold text-text-primary capitalize">{listing.status}</p>
                <p className="text-xs text-text-tertiary mt-1">
                  This property was marked {listing.status} when its booking was completed.
                  No further actions are available.
                </p>
              </div>
            )}

            {listing.status !== 'sold' && listing.status !== 'rented' && (
              <>
                {!listing.isApproved && listing.status !== 'suspended' && (
                  <button
                    onClick={() => onAction('approve', listing)}
                    disabled={actionLoading}
                    className="w-full btn-success border border-green-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
                  >
                    <CheckCircle size={15} /> Approve Listing
                  </button>
                )}
                {listing.isApproved && !listing.isFeatured && (
                  <button
                    onClick={() => onAction('feature', listing)}
                    disabled={actionLoading}
                    className="w-full btn-accent border border-green-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
                  >
                    <Star size={15} /> Feature Listing
                  </button>
                )}
                {listing.isFeatured && (
                  <button
                    onClick={() => onAction('unfeature', listing)}
                    disabled={actionLoading}
                    className="w-full btn-ghost border border-neutral-border rounded-lg py-2.5 justify-center disabled:opacity-50"
                  >
                    <Star size={15} /> Remove from Featured
                  </button>
                )}
                {listing.status !== 'suspended' && (
                  <button
                    onClick={() => onAction('reject', listing)}
                    disabled={actionLoading}
                    className="w-full btn-danger border border-red-100 rounded-lg py-2.5 justify-center disabled:opacity-50"
                  >
                    <XCircle size={15} /> Reject / Suspend
                  </button>
                )}
                {listing.status === 'suspended' && (
                  <button
                    onClick={() => onAction('reinstate', listing)}
                    disabled={actionLoading}
                    className="w-full btn-ghost border border-neutral-border rounded-lg py-2.5 justify-center disabled:opacity-50"
                  >
                    <RefreshCw size={15} /> Reinstate Listing
                  </button>
                )}
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

// ─── Main Component ───────────────────────────────────────────────────────────
export default function ListingsPage() {
  const [listings, setListings] = useState([])
  const [loading, setLoading] = useState(true)
  const [total, setTotal] = useState(0)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [typeFilter, setTypeFilter] = useState('all')
  const [page, setPage] = useState(0)
  const [cursors, setCursors] = useState([null])   // cursors[0] = null (first page)
  const [selectedListing, setSelectedListing] = useState(null)
  const [rejectTarget, setRejectTarget] = useState(null)
  const [actionLoading, setActionLoading] = useState(false)
  const [toast, setToast] = useState(null)

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3000)
  }

  // ─── Build query constraints ───────────────────────────────────────────────
  const buildConstraints = useCallback(() => {
    const c = []
    if (statusFilter === 'pending')   { c.push(where('isApproved', '==', false)); c.push(where('status', '!=', 'suspended')) }
    if (statusFilter === 'approved')  c.push(where('isApproved', '==', true))
    if (statusFilter === 'suspended') c.push(where('status', '==', 'suspended'))
    if (statusFilter === 'featured')  c.push(where('isFeatured', '==', true))
    if (statusFilter === 'sold')      c.push(where('status', '==', 'sold'))
    if (statusFilter === 'rented')    c.push(where('status', '==', 'rented'))
    if (typeFilter !== 'all')         c.push(where('type', '==', typeFilter))
    c.push(orderBy('createdAt', 'desc'))
    return c
  }, [statusFilter, typeFilter])

  // ─── Load count ───────────────────────────────────────────────────────────
  useEffect(() => {
    const loadCount = async () => {
      try {
        const constraints = buildConstraints()
        const q = query(collection(db, 'properties'), ...constraints)
        const snap = await getCountFromServer(q)
        setTotal(snap.data().count)
      } catch { setTotal(0) }
    }
    loadCount()
  }, [buildConstraints])

  // ─── Load page ────────────────────────────────────────────────────────────
  useEffect(() => {
    loadPage()
  }, [page, statusFilter, typeFilter])

  async function loadPage() {
    setLoading(true)
    try {
      const constraints = buildConstraints()
      const cursor = cursors[page]
      const q = cursor
        ? query(collection(db, 'properties'), ...constraints, startAfter(cursor), limit(PAGE_SIZE))
        : query(collection(db, 'properties'), ...constraints, limit(PAGE_SIZE))

      const snap = await getDocs(q)
      const docs = snap.docs.map(d => ({ id: d.id, ...d.data() }))
      setListings(docs)

      // Store next cursor
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

  const resetPagination = () => { setPage(0); setCursors([null]) }

  useEffect(() => { resetPagination() }, [statusFilter, typeFilter])

  // ─── Actions ──────────────────────────────────────────────────────────────
  async function handleAction(action, listing, extra) {
    setActionLoading(true)
    const ref = doc(db, 'properties', listing.id)
    try {
      switch (action) {
        case 'approve':
          await updateDoc(ref, { isApproved: true, status: 'active', approvedAt: serverTimestamp() })
          showToast('Listing approved successfully.')
          break
        case 'feature':
          await updateDoc(ref, { isFeatured: true, featuredAt: serverTimestamp() })
          showToast('Listing added to featured carousel.')
          break
        case 'unfeature':
          await updateDoc(ref, { isFeatured: false })
          showToast('Listing removed from featured.')
          break
        case 'reject':
          setRejectTarget(listing)
          setActionLoading(false)
          return
        case 'confirmReject':
          await updateDoc(ref, {
            status: 'suspended', isApproved: false,
            rejectionReason: extra, rejectedAt: serverTimestamp(),
          })
          setRejectTarget(null)
          showToast('Listing rejected and agent notified.', 'error')
          break
        case 'reinstate':
          await updateDoc(ref, { status: 'active', isApproved: true, rejectionReason: null })
          showToast('Listing reinstated.')
          break
      }
      // Refresh current page
      await loadPage()
      if (selectedListing?.id === listing.id) setSelectedListing(null)
    } catch (err) {
      console.error(err)
      showToast('Action failed. Please try again.', 'error')
    } finally {
      setActionLoading(false)
    }
  }

  // ─── Client-side search filter ─────────────────────────────────────────────
  const filtered = search.trim()
    ? listings.filter(l =>
        [l.title, l.agentId, l.type, l.listingType,
         typeof l.location === 'object'
           ? [l.location?.city, l.location?.country, l.location?.address].filter(Boolean).join(' ')
           : l.location
        ].some(v => v?.toLowerCase().includes(search.toLowerCase()))
      )
    : listings

  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="page-header">
        <div>
          <h1 className="page-title">Listings</h1>
          <p className="page-subtitle">{total.toLocaleString()} properties on the platform</p>
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
            placeholder="Search title, location, agent…"
            className="search-input pl-9"
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-text-tertiary hover:text-text-primary">
              <X size={14} />
            </button>
          )}
        </div>
        <select
          value={statusFilter}
          onChange={e => setStatusFilter(e.target.value)}
          className="filter-select"
        >
          {STATUS_OPTIONS.map(o => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
        </select>
        <select
          value={typeFilter}
          onChange={e => setTypeFilter(e.target.value)}
          className="filter-select"
        >
          {TYPE_OPTIONS.map(o => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
        </select>
        <button
          onClick={loadPage}
          className="btn-ghost border border-neutral-border rounded px-3 py-2"
        >
          <RefreshCw size={14} />
        </button>
      </div>

      {/* Table */}
      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Property</th>
                <th>Type</th>
                <th>Price</th>
                <th>Agent</th>
                <th>Listed</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i}>
                    {[200, 80, 90, 100, 80, 70, 120].map((w, j) => (
                      <td key={j}><Skeleton className={`h-4 w-${w === 200 ? 'full' : '['+w+'px]'}`} /></td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={7}>
                    <div className="empty-state">
                      <Building2 size={28} className="text-text-tertiary mb-2" />
                      <p className="text-sm text-text-secondary">No listings found</p>
                      <p className="text-xs text-text-tertiary mt-1">Try adjusting your filters.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(listing => (
                  <tr key={listing.id}>
                    {/* Property */}
                    <td>
                      <div className="flex items-center gap-3">
                        {listing.imageUrls?.[0] ? (
                          <img
                            src={listing.imageUrls[0]}
                            alt={listing.title}
                            className="w-10 h-10 rounded-lg object-cover flex-shrink-0 bg-neutral-variant"
                          />
                        ) : (
                          <div className="w-10 h-10 rounded-lg bg-neutral-variant flex items-center justify-center flex-shrink-0">
                            <Building2 size={16} className="text-text-tertiary" />
                          </div>
                        )}
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-text-primary truncate max-w-[200px]">
                            {listing.title || '—'}
                          </p>
                          <div className="flex items-center gap-1 text-xs text-text-tertiary mt-0.5">
                            <MapPin size={10} />
                            <span className="truncate max-w-[160px]">{typeof listing.location === 'object' ? [listing.location?.city, listing.location?.country].filter(Boolean).join(', ') || '—' : listing.location || '—'}</span>
                          </div>
                        </div>
                      </div>
                    </td>
                    {/* Type */}
                    <td>
                      <div className="flex flex-col gap-1">
                        <span className="capitalize text-sm text-text-primary font-medium">{listing.type || '—'}</span>
                        {listing.listingType && (
                          <span className={listing.listingType === 'rent' ? 'badge badge-accent' : 'badge badge-primary'}>
                            {listing.listingType === 'rent' ? 'Rent' : 'Sale'}
                          </span>
                        )}
                      </div>
                    </td>
                    {/* Price */}
                    <td>
                      <span className="text-sm font-semibold text-text-primary">{fmtKES(listing.price)}</span>
                    </td>
                    {/* Agent */}
                    <td>
                      <span className="text-sm text-text-secondary font-mono text-xs">
                        {listing.agentId ? listing.agentId.slice(0, 8) + '…' : '—'}
                      </span>
                    </td>
                    {/* Listed */}
                    <td>
                      <span className="text-sm text-text-secondary">{fmtDate(listing.createdAt)}</span>
                    </td>
                    {/* Status */}
                    <td><StatusBadge listing={listing} /></td>
                    {/* Actions */}
                    <td>
                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => setSelectedListing(listing)}
                          className="btn-ghost px-2 py-1.5 rounded"
                          title="View details"
                        >
                          <Eye size={14} />
                        </button>
                        {/* Sold/rented — no actions available in table row */}
                        {listing.status !== 'sold' && listing.status !== 'rented' && (
                          <>
                            {!listing.isApproved && listing.status !== 'suspended' && (
                              <button
                                onClick={() => handleAction('approve', listing)}
                                className="btn-success"
                                title="Approve"
                                disabled={actionLoading}
                              >
                                <CheckCircle size={13} /> Approve
                              </button>
                            )}
                            {listing.isApproved && !listing.isFeatured && (
                              <button
                                onClick={() => handleAction('feature', listing)}
                                className="btn-accent"
                                title="Feature"
                                disabled={actionLoading}
                              >
                                <Star size={13} /> Feature
                              </button>
                            )}
                            {listing.status !== 'suspended' && listing.isApproved && (
                              <button
                                onClick={() => handleAction('reject', listing)}
                                className="btn-danger"
                                title="Reject"
                                disabled={actionLoading}
                              >
                                <XCircle size={13} />
                              </button>
                            )}
                            {listing.status === 'suspended' && (
                              <button
                                onClick={() => handleAction('reinstate', listing)}
                                className="btn-ghost border border-neutral-border"
                                title="Reinstate"
                                disabled={actionLoading}
                              >
                                <RefreshCw size={13} />
                              </button>
                            )}
                          </>
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
              <span className="text-xs text-text-secondary px-1">
                {page + 1} / {totalPages}
              </span>
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

      {/* Detail drawer */}
      {selectedListing && (
        <ListingDrawer
          listing={selectedListing}
          onClose={() => setSelectedListing(null)}
          onAction={handleAction}
          actionLoading={actionLoading}
        />
      )}

      {/* Reject modal */}
      {rejectTarget && (
        <RejectModal
          listing={rejectTarget}
          onClose={() => setRejectTarget(null)}
          onConfirm={reason => handleAction('confirmReject', rejectTarget, reason)}
          loading={actionLoading}
        />
      )}

      {/* Toast */}
      {toast && (
        <div className={clsx(
          'fixed bottom-6 right-6 z-50 flex items-center gap-2.5 px-4 py-3 rounded-lg shadow-lg text-sm font-medium animate-slide-up',
          toast.type === 'error'
            ? 'bg-status-error text-white'
            : 'bg-text-primary text-white'
        )}>
          {toast.type === 'error'
            ? <XCircle size={15} />
            : <CheckCircle size={15} />}
          {toast.msg}
        </div>
      )}
    </div>
  )
}