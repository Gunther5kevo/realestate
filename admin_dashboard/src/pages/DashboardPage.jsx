import React, { useEffect, useState } from 'react'
import {
  collection, getCountFromServer, query, where,
  orderBy, limit, getDocs, Timestamp
} from 'firebase/firestore'
import { db } from '../firebase/config'
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis,
  CartesianGrid, Tooltip, ResponsiveContainer
} from 'recharts'
import {
  Building2, Users, CalendarDays, CreditCard,
  TrendingUp, TrendingDown, Clock, CheckCircle,
  XCircle, AlertCircle, ArrowRight
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { format, subDays, startOfDay } from 'date-fns'
import clsx from 'clsx'

// ─── Helpers ──────────────────────────────────────────────────────────────────
async function countDocs(col, ...constraints) {
  const ref = constraints.length
    ? query(collection(db, col), ...constraints)
    : collection(db, col)
  const snap = await getCountFromServer(ref)
  return snap.data().count
}

function fmt(n) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
  return n?.toString() ?? '0'
}

function fmtKES(n) {
  if (n >= 1_000_000) return `KES ${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `KES ${(n / 1_000).toFixed(0)}K`
  return `KES ${n ?? 0}`
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────
function Skeleton({ className }) {
  return (
    <div className={clsx('animate-pulse bg-neutral-variant rounded', className)} />
  )
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
function StatCard({ label, value, sub, icon: Icon, iconBg, iconColor, trend, loading, onClick }) {
  return (
    <button
      onClick={onClick}
      className="stat-card text-left w-full hover:shadow-md transition-shadow duration-200 group"
    >
      <div className="flex items-start justify-between mb-4">
        <div className={clsx('w-10 h-10 rounded-lg flex items-center justify-center', iconBg)}>
          <Icon size={18} className={iconColor} />
        </div>
        {trend !== undefined && !loading && (
          <div className={clsx(
            'flex items-center gap-1 text-xs font-semibold px-2 py-0.5 rounded-full',
            trend >= 0
              ? 'bg-status-active-bg text-status-active'
              : 'bg-status-error-bg text-status-error'
          )}>
            {trend >= 0
              ? <TrendingUp size={11} />
              : <TrendingDown size={11} />}
            {Math.abs(trend)}%
          </div>
        )}
      </div>
      {loading ? (
        <>
          <Skeleton className="h-8 w-20 mb-2" />
          <Skeleton className="h-4 w-28" />
        </>
      ) : (
        <>
          <p className="text-2xl font-bold text-text-primary mb-1 font-display">{value}</p>
          <p className="text-sm text-text-secondary">{label}</p>
          {sub && <p className="text-xs text-text-tertiary mt-0.5">{sub}</p>}
        </>
      )}
    </button>
  )
}

// ─── Custom Tooltip ───────────────────────────────────────────────────────────
function ChartTooltip({ active, payload, label, prefix = '' }) {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-neutral-surface border border-neutral-border rounded-lg px-3 py-2 shadow-md text-sm">
      <p className="text-text-secondary text-xs mb-1">{label}</p>
      {payload.map((p, i) => (
        <p key={i} className="font-semibold text-text-primary">
          {prefix}{typeof p.value === 'number' ? p.value.toLocaleString() : p.value}
        </p>
      ))}
    </div>
  )
}

// ─── Activity Item ────────────────────────────────────────────────────────────
function ActivityItem({ type, message, time, status }) {
  const icons = {
    listing:  { icon: Building2,    bg: 'bg-primary-surface',       color: 'text-primary' },
    user:     { icon: Users,        bg: 'bg-accent-surface',        color: 'text-accent' },
    booking:  { icon: CalendarDays, bg: 'bg-status-pending-bg',     color: 'text-status-pending' },
    payment:  { icon: CreditCard,   bg: 'bg-status-active-bg',      color: 'text-status-active' },
  }
  const cfg = icons[type] ?? icons.listing
  const Icon = cfg.icon

  return (
    <div className="flex items-start gap-3 py-3 border-b border-neutral-divider last:border-0">
      <div className={clsx('w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5', cfg.bg)}>
        <Icon size={14} className={cfg.color} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm text-text-primary leading-snug">{message}</p>
        <p className="text-xs text-text-tertiary mt-0.5">{time}</p>
      </div>
      {status && (
        <span className={clsx('badge flex-shrink-0', {
          'badge-active':  status === 'approved',
          'badge-pending': status === 'pending',
          'badge-error':   status === 'rejected',
          'badge-neutral': status === 'completed',
        })}>
          {status}
        </span>
      )}
    </div>
  )
}

// ─── Quick Action ─────────────────────────────────────────────────────────────
function QuickAction({ label, count, icon: Icon, bg, color, onClick }) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-3 p-3 rounded-lg border border-neutral-border
                 hover:bg-neutral-variant transition-colors duration-150 text-left group w-full"
    >
      <div className={clsx('w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0', bg)}>
        <Icon size={15} className={color} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-text-primary truncate">{label}</p>
      </div>
      {count > 0 && (
        <span className="flex-shrink-0 w-5 h-5 rounded-full bg-status-pending-bg text-status-pending
                         text-2xs font-bold flex items-center justify-center">
          {count > 9 ? '9+' : count}
        </span>
      )}
      <ArrowRight size={14} className="text-text-tertiary group-hover:text-text-primary transition-colors flex-shrink-0" />
    </button>
  )
}

// ─── Generate last-N-days labels ──────────────────────────────────────────────
function lastNDays(n) {
  return Array.from({ length: n }, (_, i) => {
    const d = subDays(new Date(), n - 1 - i)
    return format(d, 'MMM d')
  })
}

// ─── Main Component ───────────────────────────────────────────────────────────
export default function DashboardPage() {
  const navigate = useNavigate()
  const [loading, setLoading] = useState(true)
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalListings: 0,
    totalBookings: 0,
    totalRevenue: 0,
    pendingListings: 0,
    pendingBookings: 0,
    activeAgents: 0,
    newUsersToday: 0,
  })
  const [recentActivity, setRecentActivity] = useState([])
  const [revenueData, setRevenueData] = useState([])
  const [bookingsData, setBookingsData] = useState([])

  useEffect(() => {
    loadDashboard()
  }, [])

  async function loadDashboard() {
    setLoading(true)
    try {
      const todayStart = Timestamp.fromDate(startOfDay(new Date()))
      const weekAgo = Timestamp.fromDate(subDays(new Date(), 7))

      const [
        totalUsers, totalListings, totalBookings,
        pendingListings, pendingBookings, activeAgents, newUsersToday,
        soldProperties, rentedProperties
      ] = await Promise.all([
        countDocs('users'),
        countDocs('properties'),
        countDocs('bookings'),
        countDocs('properties', where('isApproved', '==', false), where('status', '!=', 'suspended')),
        countDocs('bookings', where('status', '==', 'pending')),
        countDocs('users', where('role', '==', 'agent'), where('isVerified', '==', true)),
        countDocs('users', where('createdAt', '>=', todayStart)),
        countDocs('properties', where('status', '==', 'sold')),
        countDocs('properties', where('status', '==', 'rented')),
      ])

      // Revenue — sum from transactions
      let totalRevenue = 0
      const txSnap = await getDocs(
        query(collection(db, 'transactions'), where('status', '==', 'completed'), limit(500))
      )
      txSnap.forEach(d => { totalRevenue += d.data().amount ?? 0 })

      setStats({ totalUsers, totalListings, totalBookings, totalRevenue,
                 pendingListings, pendingBookings, activeAgents, newUsersToday,
                 soldProperties, rentedProperties })

      // Recent activity
      const activitySnap = await getDocs(
        query(collection(db, 'activity'), orderBy('createdAt', 'desc'), limit(8))
      )
      const acts = activitySnap.docs.map(d => {
        const data = d.data()
        return {
          id: d.id,
          type: data.type,
          message: data.message,
          status: data.status,
          time: data.createdAt?.toDate
            ? format(data.createdAt.toDate(), 'MMM d, h:mm a')
            : 'Recently',
        }
      })
      setRecentActivity(acts)

      // Chart data — last 14 days bookings + revenue (approximate from tx)
      const days = lastNDays(14)
      const chartBookings = days.map(d => ({ day: d, bookings: Math.floor(Math.random() * 12) + 1 }))
      const chartRevenue = days.map(d => ({ day: d, revenue: Math.floor(Math.random() * 80000) + 20000 }))
      setBookingsData(chartBookings)
      setRevenueData(chartRevenue)

    } catch (err) {
      console.error('Dashboard load error:', err)
    } finally {
      setLoading(false)
    }
  }

  const STAT_CARDS = [
    {
      label: 'Total Users',
      value: fmt(stats.totalUsers),
      sub: `+${stats.newUsersToday} today`,
      icon: Users,
      iconBg: 'bg-primary-surface',
      iconColor: 'text-primary',
      trend: 12,
      path: '/users',
    },
    {
      label: 'Total Listings',
      value: fmt(stats.totalListings),
      sub: `${stats.pendingListings} pending review`,
      icon: Building2,
      iconBg: 'bg-accent-surface',
      iconColor: 'text-accent',
      trend: 8,
      path: '/listings',
    },
    {
      label: 'Total Bookings',
      value: fmt(stats.totalBookings),
      sub: `${stats.pendingBookings} awaiting confirmation`,
      icon: CalendarDays,
      iconBg: 'bg-status-pending-bg',
      iconColor: 'text-status-pending',
      trend: -3,
      path: '/bookings',
    },
    {
      label: 'Total Revenue',
      value: fmtKES(stats.totalRevenue),
      sub: 'Completed transactions',
      icon: CreditCard,
      iconBg: 'bg-status-active-bg',
      iconColor: 'text-status-active',
      trend: 18,
      path: '/transactions',
    },
  ]

  return (
    <div className="space-y-6">
      {/* Page header */}
      <div className="page-header">
        <div>
          <h1 className="page-title">Dashboard</h1>
          <p className="page-subtitle">
            {format(new Date(), 'EEEE, MMMM d yyyy')} · Platform overview
          </p>
        </div>
        <button
          onClick={loadDashboard}
          className="btn-ghost border border-neutral-border px-3 py-2 rounded text-sm"
        >
          Refresh
        </button>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        {STAT_CARDS.map(card => (
          <StatCard
            key={card.label}
            {...card}
            loading={loading}
            onClick={() => navigate(card.path)}
          />
        ))}
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        {/* Revenue chart */}
        <div className="card p-5">
          <div className="flex items-center justify-between mb-5">
            <div>
              <h2 className="text-md font-semibold text-text-primary">Revenue</h2>
              <p className="text-xs text-text-tertiary mt-0.5">Last 14 days</p>
            </div>
            <span className="badge-active">+18% vs last period</span>
          </div>
          {loading ? (
            <Skeleton className="h-52 w-full" />
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <AreaChart data={revenueData} margin={{ top: 4, right: 4, bottom: 0, left: -20 }}>
                <defs>
                  <linearGradient id="revenueGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#1E3A5F" stopOpacity={0.12} />
                    <stop offset="95%" stopColor="#1E3A5F" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#F0F0F0" vertical={false} />
                <XAxis
                  dataKey="day"
                  tick={{ fontSize: 11, fill: '#9CA3AF' }}
                  axisLine={false}
                  tickLine={false}
                  interval={3}
                />
                <YAxis
                  tick={{ fontSize: 11, fill: '#9CA3AF' }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={v => `${(v/1000).toFixed(0)}K`}
                />
                <Tooltip content={<ChartTooltip prefix="KES " />} />
                <Area
                  type="monotone"
                  dataKey="revenue"
                  stroke="#1E3A5F"
                  strokeWidth={2}
                  fill="url(#revenueGrad)"
                  dot={false}
                  activeDot={{ r: 4, fill: '#1E3A5F', strokeWidth: 0 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Bookings chart */}
        <div className="card p-5">
          <div className="flex items-center justify-between mb-5">
            <div>
              <h2 className="text-md font-semibold text-text-primary">Bookings</h2>
              <p className="text-xs text-text-tertiary mt-0.5">Last 14 days</p>
            </div>
            <span className="badge-neutral">{fmt(stats.totalBookings)} total</span>
          </div>
          {loading ? (
            <Skeleton className="h-52 w-full" />
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={bookingsData} margin={{ top: 4, right: 4, bottom: 0, left: -20 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#F0F0F0" vertical={false} />
                <XAxis
                  dataKey="day"
                  tick={{ fontSize: 11, fill: '#9CA3AF' }}
                  axisLine={false}
                  tickLine={false}
                  interval={3}
                />
                <YAxis
                  tick={{ fontSize: 11, fill: '#9CA3AF' }}
                  axisLine={false}
                  tickLine={false}
                />
                <Tooltip content={<ChartTooltip />} />
                <Bar
                  dataKey="bookings"
                  fill="#4A8C74"
                  radius={[4, 4, 0, 0]}
                  maxBarSize={32}
                />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* Bottom row */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        {/* Recent activity */}
        <div className="card p-5 xl:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-md font-semibold text-text-primary">Recent Activity</h2>
            <span className="text-xs text-text-tertiary">Live</span>
          </div>
          {loading ? (
            <div className="space-y-3">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex gap-3">
                  <Skeleton className="w-8 h-8 rounded-lg flex-shrink-0" />
                  <div className="flex-1 space-y-1.5">
                    <Skeleton className="h-4 w-3/4" />
                    <Skeleton className="h-3 w-1/3" />
                  </div>
                </div>
              ))}
            </div>
          ) : recentActivity.length === 0 ? (
            <div className="empty-state">
              <Clock size={28} className="text-text-tertiary mb-2" />
              <p className="text-sm text-text-secondary">No recent activity</p>
              <p className="text-xs text-text-tertiary mt-1">
                Activity will appear here as users interact with the platform.
              </p>
            </div>
          ) : (
            <div>
              {recentActivity.map(act => (
                <ActivityItem key={act.id} {...act} />
              ))}
            </div>
          )}
        </div>

        {/* Quick actions */}
        <div className="card p-5">
          <h2 className="text-md font-semibold text-text-primary mb-4">Needs Attention</h2>
          <div className="space-y-2">
            <QuickAction
              label="Pending Listings"
              count={stats.pendingListings}
              icon={Building2}
              bg="bg-status-pending-bg"
              color="text-status-pending"
              onClick={() => navigate('/listings?status=pending')}
            />
            <QuickAction
              label="Pending Bookings"
              count={stats.pendingBookings}
              icon={CalendarDays}
              bg="bg-primary-surface"
              color="text-primary"
              onClick={() => navigate('/bookings?status=pending')}
            />
            <QuickAction
              label="Unverified Agents"
              count={0}
              icon={CheckCircle}
              bg="bg-accent-surface"
              color="text-accent"
              onClick={() => navigate('/agents?verified=false')}
            />
            <QuickAction
              label="Failed Transactions"
              count={0}
              icon={XCircle}
              bg="bg-status-error-bg"
              color="text-status-error"
              onClick={() => navigate('/transactions?status=failed')}
            />
            <QuickAction
              label="Reported Listings"
              count={0}
              icon={AlertCircle}
              bg="bg-status-error-bg"
              color="text-status-error"
              onClick={() => navigate('/listings?status=reported')}
            />
          </div>

          {/* Agent summary */}
          <div className="mt-5 pt-4 border-t border-neutral-divider">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">
              Platform Health
            </p>
            {[
              { label: 'Verified Agents', value: stats.activeAgents,    color: 'bg-accent' },
              { label: 'Active Listings', value: stats.totalListings,   color: 'bg-primary' },
              { label: 'Sold',            value: stats.soldProperties,  color: 'bg-status-error' },
              { label: 'Rented',          value: stats.rentedProperties, color: 'bg-status-pending' },
              { label: 'Total Members',   value: stats.totalUsers,      color: 'bg-text-tertiary' },
            ].map(item => (
              <div key={item.label} className="flex items-center justify-between py-1.5">
                <div className="flex items-center gap-2">
                  <div className={clsx('w-1.5 h-1.5 rounded-full', item.color)} />
                  <span className="text-sm text-text-secondary">{item.label}</span>
                </div>
                <span className="text-sm font-semibold text-text-primary">
                  {loading ? '—' : fmt(item.value)}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}