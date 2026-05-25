import React, { useState } from 'react'
import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { signOut } from 'firebase/auth'
import { auth } from '../firebase/config'
import { useAuth } from '../App'
import {
  LayoutDashboard, Building2, Users, UserCheck,
  CalendarDays, CreditCard, Bell, LogOut,
  ChevronLeft, ChevronRight, Menu, X
} from 'lucide-react'
import clsx from 'clsx'

// ─── Nav Items ────────────────────────────────────────────────────────────────
const NAV_ITEMS = [
  { to: '/',              label: 'Dashboard',     icon: LayoutDashboard, end: true },
  { to: '/listings',      label: 'Listings',      icon: Building2 },
  { to: '/users',         label: 'Users',         icon: Users },
  { to: '/agents',        label: 'Agents',        icon: UserCheck },
  { to: '/bookings',      label: 'Bookings',      icon: CalendarDays },
  { to: '/transactions',  label: 'Transactions',  icon: CreditCard },
  { to: '/notifications', label: 'Notifications', icon: Bell },
]

// ─── Sidebar ──────────────────────────────────────────────────────────────────
function Sidebar({ collapsed, onToggle, mobileOpen, onMobileClose }) {
  const navigate = useNavigate()
  const { user } = useAuth()

  const handleSignOut = async () => {
    await signOut(auth)
    navigate('/login')
  }

  const sidebarContent = (
    <div className="flex flex-col h-full">
      {/* Logo */}
      <div className={clsx(
        'flex items-center gap-3 px-4 border-b border-neutral-border',
        collapsed ? 'justify-center py-5' : 'justify-between py-4'
      )}>
        {!collapsed && (
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center flex-shrink-0">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
                <polyline points="9 22 9 12 15 12 15 22" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <div>
              <span className="font-display text-lg text-text-primary leading-none">NestIQ</span>
              <span className="block text-2xs font-semibold text-text-tertiary tracking-widest uppercase leading-none mt-0.5">Admin</span>
            </div>
          </div>
        )}
        {collapsed && (
          <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
              <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
              <polyline points="9 22 9 12 15 12 15 22" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
        )}
        {/* Desktop collapse toggle */}
        <button
          onClick={onToggle}
          className="hidden lg:flex items-center justify-center w-6 h-6 rounded text-text-tertiary hover:text-text-primary hover:bg-neutral-variant transition-colors"
        >
          {collapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
        </button>
        {/* Mobile close */}
        <button
          onClick={onMobileClose}
          className="lg:hidden flex items-center justify-center w-6 h-6 rounded text-text-tertiary hover:text-text-primary"
        >
          <X size={16} />
        </button>
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-3 px-2 space-y-0.5">
        {NAV_ITEMS.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            onClick={onMobileClose}
            className={({ isActive }) => clsx(
              'flex items-center gap-3 rounded px-3 py-2.5 text-sm font-medium transition-all duration-150 group',
              isActive
                ? 'bg-primary text-white'
                : 'text-text-secondary hover:bg-neutral-variant hover:text-text-primary'
            )}
          >
            {({ isActive }) => (
              <>
                <Icon size={17} className="flex-shrink-0" />
                {!collapsed && (
                  <span className="truncate">{label}</span>
                )}
                {collapsed && (
                  <span className="
                    absolute left-full ml-2 px-2 py-1 bg-text-primary text-white text-xs rounded
                    opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap
                    transition-opacity duration-150 z-50
                  ">
                    {label}
                  </span>
                )}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* User footer */}
      <div className={clsx(
        'border-t border-neutral-border p-3',
        collapsed ? 'flex justify-center' : ''
      )}>
        {!collapsed ? (
          <div className="flex items-center gap-3">
            <Avatar email={user?.email} size="sm" />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-text-primary truncate">
                {user?.displayName || 'Admin'}
              </p>
              <p className="text-2xs text-text-tertiary truncate">{user?.email}</p>
            </div>
            <button
              onClick={handleSignOut}
              title="Sign out"
              className="w-7 h-7 flex items-center justify-center rounded text-text-tertiary hover:text-status-error hover:bg-status-error-bg transition-colors"
            >
              <LogOut size={15} />
            </button>
          </div>
        ) : (
          <button
            onClick={handleSignOut}
            title="Sign out"
            className="w-8 h-8 flex items-center justify-center rounded text-text-tertiary hover:text-status-error hover:bg-status-error-bg transition-colors"
          >
            <LogOut size={16} />
          </button>
        )}
      </div>
    </div>
  )

  return (
    <>
      {/* Desktop sidebar */}
      <aside className={clsx(
        'hidden lg:flex flex-col flex-shrink-0 bg-neutral-surface border-r border-neutral-border',
        'transition-all duration-200 ease-in-out overflow-hidden',
        collapsed ? 'w-16' : 'w-56'
      )}>
        {sidebarContent}
      </aside>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/30 lg:hidden animate-fade-in"
          onClick={onMobileClose}
        />
      )}

      {/* Mobile drawer */}
      <aside className={clsx(
        'fixed inset-y-0 left-0 z-50 w-64 bg-neutral-surface border-r border-neutral-border',
        'flex flex-col lg:hidden transition-transform duration-250 ease-out',
        mobileOpen ? 'translate-x-0' : '-translate-x-full'
      )}>
        {sidebarContent}
      </aside>
    </>
  )
}

// ─── Top Nav ──────────────────────────────────────────────────────────────────
function TopNav({ onMobileMenuOpen }) {
  const { user } = useAuth()
  const navigate = useNavigate()

  // Derive current page title from pathname
  const path = window.location.pathname
  const currentNav = NAV_ITEMS.find(n => {
    if (n.end) return path === '/'
    return path.startsWith(n.to)
  })

  return (
    <header className="h-14 flex-shrink-0 bg-neutral-surface border-b border-neutral-border flex items-center px-4 gap-4">
      {/* Mobile menu button */}
      <button
        onClick={onMobileMenuOpen}
        className="lg:hidden w-8 h-8 flex items-center justify-center rounded text-text-secondary hover:bg-neutral-variant transition-colors"
      >
        <Menu size={18} />
      </button>

      {/* Page title */}
      <div className="flex-1">
        <h1 className="text-md font-semibold text-text-primary">
          {currentNav?.label ?? 'NestIQ Admin'}
        </h1>
      </div>

      {/* Right actions */}
      <div className="flex items-center gap-2">
        <button
          onClick={() => navigate('/notifications')}
          className="relative w-8 h-8 flex items-center justify-center rounded text-text-secondary hover:bg-neutral-variant transition-colors"
          title="Notifications"
        >
          <Bell size={17} />
          <span className="absolute top-1.5 right-1.5 w-1.5 h-1.5 rounded-full bg-status-error" />
        </button>

        <button className="flex items-center gap-2 pl-2 pr-3 py-1.5 rounded hover:bg-neutral-variant transition-colors group">
          <Avatar email={user?.email} size="xs" />
          <span className="text-sm font-medium text-text-primary hidden sm:block">
            {user?.displayName || user?.email?.split('@')[0] || 'Admin'}
          </span>
        </button>
      </div>
    </header>
  )
}

// ─── Avatar Helper ────────────────────────────────────────────────────────────
export function Avatar({ email, size = 'sm' }) {
  const initials = email
    ? email.slice(0, 2).toUpperCase()
    : 'AD'
  const sizes = { xs: 'w-7 h-7 text-2xs', sm: 'w-8 h-8 text-xs' }
  return (
    <div className={clsx(
      'rounded-lg bg-primary-surface text-primary font-bold flex items-center justify-center flex-shrink-0',
      sizes[size]
    )}>
      {initials}
    </div>
  )
}

// ─── Layout Shell ─────────────────────────────────────────────────────────────
export default function Layout() {
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)

  return (
    <div className="flex h-screen overflow-hidden bg-neutral-bg">
      <Sidebar
        collapsed={collapsed}
        onToggle={() => setCollapsed(c => !c)}
        mobileOpen={mobileOpen}
        onMobileClose={() => setMobileOpen(false)}
      />

      <div className="flex flex-col flex-1 min-w-0 overflow-hidden">
        <TopNav onMobileMenuOpen={() => setMobileOpen(true)} />

        <main className="flex-1 overflow-y-auto">
          <div className="p-6 max-w-screen-xl mx-auto animate-slide-up">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  )
}