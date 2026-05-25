import React, { createContext, useContext, useEffect, useState } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { onAuthStateChanged } from 'firebase/auth'
import { doc, getDoc } from 'firebase/firestore'
import { auth, db } from './firebase/config'

import Layout from './components/Layout'
import LoginPage from './pages/LoginPage'
import DashboardPage from './pages/DashboardPage'
import ListingsPage from './pages/ListingsPage'
import UsersPage from './pages/UsersPage'
import AgentsPage from './pages/AgentsPage'
import BookingsPage from './pages/BookingsPage'
import TransactionsPage from './pages/TransactionsPage'
import NotificationsPage from './pages/NotificationsPage'

// ─── Auth Context ────────────────────────────────────────────────────────────
const AuthContext = createContext(null)

export const useAuth = () => {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}

function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [role, setRole] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        try {
          const userDoc = await getDoc(doc(db, 'users', firebaseUser.uid))
          const data = userDoc.data()
          setUser(firebaseUser)
          setRole(data?.role ?? null)
        } catch {
          setUser(firebaseUser)
          setRole(null)
        }
      } else {
        setUser(null)
        setRole(null)
      }
      setLoading(false)
    })
    return unsub
  }, [])

  return (
    <AuthContext.Provider value={{ user, role, loading }}>
      {children}
    </AuthContext.Provider>
  )
}

// ─── Route Guards ─────────────────────────────────────────────────────────────
function RequireAdmin({ children }) {
  const { user, role, loading } = useAuth()

  if (loading) return <FullScreenLoader />
  if (!user) return <Navigate to="/login" replace />
  if (role !== 'admin') return <AccessDenied />

  return children
}

function RedirectIfAuthed({ children }) {
  const { user, role, loading } = useAuth()
  if (loading) return <FullScreenLoader />
  if (user && role === 'admin') return <Navigate to="/" replace />
  return children
}

// ─── Loading & Error States ───────────────────────────────────────────────────
function FullScreenLoader() {
  return (
    <div className="fixed inset-0 bg-neutral-bg flex items-center justify-center">
      <div className="flex flex-col items-center gap-4">
        <div className="w-10 h-10 rounded-lg bg-primary flex items-center justify-center">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
            <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            <polyline points="9 22 9 12 15 12 15 22" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
        <div className="flex gap-1">
          {[0, 1, 2].map(i => (
            <div
              key={i}
              className="w-1.5 h-1.5 rounded-full bg-primary animate-bounce"
              style={{ animationDelay: `${i * 150}ms` }}
            />
          ))}
        </div>
      </div>
    </div>
  )
}

function AccessDenied() {
  return (
    <div className="fixed inset-0 bg-neutral-bg flex items-center justify-center">
      <div className="text-center max-w-sm px-6">
        <div className="w-14 h-14 rounded-lg bg-status-error-bg flex items-center justify-center mx-auto mb-4">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" stroke="#DC2626" strokeWidth="2"/>
            <line x1="15" y1="9" x2="9" y2="15" stroke="#DC2626" strokeWidth="2" strokeLinecap="round"/>
            <line x1="9" y1="9" x2="15" y2="15" stroke="#DC2626" strokeWidth="2" strokeLinecap="round"/>
          </svg>
        </div>
        <h2 className="font-display text-2xl text-text-primary mb-2">Access Denied</h2>
        <p className="text-sm text-text-secondary mb-5">
          Your account does not have admin privileges. Contact a system administrator.
        </p>
        <button
          onClick={() => auth.signOut()}
          className="btn-primary px-5 py-2 rounded text-sm font-semibold"
        >
          Sign out
        </button>
      </div>
    </div>
  )
}

// ─── Router ───────────────────────────────────────────────────────────────────
function AppRouter() {
  return (
    <Routes>
      <Route
        path="/login"
        element={
          <RedirectIfAuthed>
            <LoginPage />
          </RedirectIfAuthed>
        }
      />
      <Route
        path="/"
        element={
          <RequireAdmin>
            <Layout />
          </RequireAdmin>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route path="listings" element={<ListingsPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="agents" element={<AgentsPage />} />
        <Route path="bookings" element={<BookingsPage />} />
        <Route path="transactions" element={<TransactionsPage />} />
        <Route path="notifications" element={<NotificationsPage />} />
      </Route>

      {/* Catch-all */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRouter />
      </AuthProvider>
    </BrowserRouter>
  )
}