import React, { useState } from 'react'
import { signInWithEmailAndPassword } from 'firebase/auth'
import { doc, getDoc } from 'firebase/firestore'
import { auth, db } from '../firebase/config'
import { useNavigate } from 'react-router-dom'
import { Eye, EyeOff, AlertCircle } from 'lucide-react'

const ERROR_MESSAGES = {
  'auth/invalid-credential':   'Incorrect email or password.',
  'auth/user-not-found':       'No account found with this email.',
  'auth/wrong-password':       'Incorrect password.',
  'auth/too-many-requests':    'Too many attempts. Try again later.',
  'auth/user-disabled':        'This account has been disabled.',
  'auth/invalid-email':        'Please enter a valid email address.',
  'auth/network-request-failed': 'Network error. Check your connection.',
}

export default function LoginPage() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    if (!email.trim() || !password.trim()) {
      setError('Please enter your email and password.')
      return
    }

    setLoading(true)
    try {
      const credential = await signInWithEmailAndPassword(auth, email.trim(), password)
      const userDoc = await getDoc(doc(db, 'users', credential.user.uid))
      const role = userDoc.data()?.role

      if (role !== 'admin') {
        await auth.signOut()
        setError('Your account does not have admin access.')
        return
      }

      navigate('/', { replace: true })
    } catch (err) {
      setError(ERROR_MESSAGES[err.code] || 'Sign in failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-neutral-bg flex">
      {/* Left panel — branding */}
      <div className="hidden lg:flex lg:w-[480px] xl:w-[560px] bg-primary flex-col justify-between p-12 flex-shrink-0 relative overflow-hidden">
        {/* Background pattern */}
        <div className="absolute inset-0 opacity-5">
          <svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <pattern id="grid" width="48" height="48" patternUnits="userSpaceOnUse">
                <path d="M 48 0 L 0 0 0 48" fill="none" stroke="white" strokeWidth="1"/>
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#grid)" />
          </svg>
        </div>
        {/* Decorative circles */}
        <div className="absolute -bottom-24 -left-24 w-80 h-80 rounded-full bg-white opacity-5" />
        <div className="absolute -top-16 -right-16 w-64 h-64 rounded-full bg-white opacity-5" />

        {/* Logo */}
        <div className="relative flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-white/15 flex items-center justify-center">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              <polyline points="9 22 9 12 15 12 15 22" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <div>
            <span className="font-display text-xl text-white leading-none">NestIQ</span>
            <span className="block text-2xs font-semibold text-white/50 tracking-widest uppercase mt-0.5">Admin Console</span>
          </div>
        </div>

        {/* Hero text */}
        <div className="relative">
          <h2 className="font-display text-4xl text-white leading-snug mb-4">
            Manage your<br />real estate platform
          </h2>
          <p className="text-white/60 text-base leading-relaxed max-w-xs">
            Approve listings, manage users and agents, track bookings, and oversee transactions — all in one place.
          </p>

          {/* Stats row */}
          <div className="flex gap-8 mt-10">
            {[
              { label: 'Properties', value: 'Listings' },
              { label: 'Verified',   value: 'Agents' },
              { label: 'Processed',  value: 'Bookings' },
            ].map(s => (
              <div key={s.label}>
                <p className="text-white/40 text-xs font-medium uppercase tracking-wider">{s.label}</p>
                <p className="text-white font-semibold text-base mt-0.5">{s.value}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Footer */}
        <p className="relative text-white/30 text-xs">
          © {new Date().getFullYear()} NestIQ. All rights reserved.
        </p>
      </div>

      {/* Right panel — form */}
      <div className="flex-1 flex items-center justify-center p-6">
        <div className="w-full max-w-md animate-slide-up">
          {/* Mobile logo */}
          <div className="flex items-center gap-2.5 mb-8 lg:hidden">
            <div className="w-9 h-9 rounded-lg bg-primary flex items-center justify-center">
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none">
                <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
                <polyline points="9 22 9 12 15 12 15 22" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <span className="font-display text-xl text-text-primary">NestIQ Admin</span>
          </div>

          <div className="mb-8">
            <h1 className="font-display text-3xl text-text-primary mb-1.5">Welcome back</h1>
            <p className="text-sm text-text-secondary">Sign in to your admin account to continue.</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email */}
            <div>
              <label className="block text-sm font-medium text-text-primary mb-1.5">
                Email address
              </label>
              <input
                type="email"
                autoComplete="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="admin@nestiq.co"
                disabled={loading}
                className="w-full bg-neutral-variant border border-neutral-border rounded px-3.5 py-2.5
                           text-base text-text-primary placeholder:text-text-tertiary
                           focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary
                           disabled:opacity-50 transition-all duration-150"
              />
            </div>

            {/* Password */}
            <div>
              <label className="block text-sm font-medium text-text-primary mb-1.5">
                Password
              </label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  disabled={loading}
                  className="w-full bg-neutral-variant border border-neutral-border rounded px-3.5 py-2.5 pr-11
                             text-base text-text-primary placeholder:text-text-tertiary
                             focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary
                             disabled:opacity-50 transition-all duration-150"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(v => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-text-tertiary hover:text-text-secondary transition-colors"
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            {/* Error */}
            {error && (
              <div className="flex items-start gap-2.5 px-3.5 py-3 rounded bg-status-error-bg border border-red-100 animate-fade-in">
                <AlertCircle size={15} className="text-status-error flex-shrink-0 mt-0.5" />
                <p className="text-sm text-status-error">{error}</p>
              </div>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-primary hover:bg-primary-light text-white font-semibold text-md
                         rounded py-2.5 mt-2 transition-all duration-150
                         disabled:opacity-60 disabled:cursor-not-allowed
                         flex items-center justify-center gap-2"
            >
              {loading ? (
                <>
                  <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  Signing in…
                </>
              ) : (
                'Sign in'
              )}
            </button>
          </form>

          <p className="text-center text-xs text-text-tertiary mt-8">
            Admin access only. Unauthorised access is prohibited.
          </p>
        </div>
      </div>
    </div>
  )
}