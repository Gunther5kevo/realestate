/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#1E3A5F',
          light: '#2D5183',
          surface: '#EBF0F7',
        },
        accent: {
          DEFAULT: '#4A8C74',
          light: '#6BAF96',
          surface: '#EAF3EE',
        },
        neutral: {
          bg: '#F8F9FA',
          surface: '#FFFFFF',
          variant: '#F2F4F7',
          border: '#E5E7EB',
          'border-light': '#F3F4F6',
          divider: '#F0F0F0',
        },
        text: {
          primary: '#111827',
          secondary: '#6B7280',
          tertiary: '#9CA3AF',
          'on-primary': '#FFFFFF',
        },
        status: {
          active: '#059669',
          'active-bg': '#ECFDF5',
          pending: '#D97706',
          'pending-bg': '#FFFBEB',
          error: '#DC2626',
          'error-bg': '#FEF2F2',
          sold: '#6B7280',
          rented: '#4A8C74',
        },
      },
      fontFamily: {
        sans: ['"DM Sans"', 'sans-serif'],
        display: ['"DM Serif Display"', 'serif'],
      },
      fontSize: {
        '2xs': ['11px', { lineHeight: '1.4', letterSpacing: '0.03em' }],
        xs: ['12px', { lineHeight: '1.5', letterSpacing: '0.02em' }],
        sm: ['13px', { lineHeight: '1.5' }],
        base: ['14px', { lineHeight: '1.55' }],
        md: ['15px', { lineHeight: '1.5' }],
        lg: ['16px', { lineHeight: '1.6' }],
        xl: ['18px', { lineHeight: '1.4', letterSpacing: '-0.01em' }],
        '2xl': ['22px', { lineHeight: '1.3', letterSpacing: '-0.02em' }],
        '3xl': ['26px', { lineHeight: '1.25' }],
        '4xl': ['32px', { lineHeight: '1.2', letterSpacing: '-0.03em' }],
        '5xl': ['40px', { lineHeight: '1.15', letterSpacing: '-0.05em' }],
      },
      borderRadius: {
        sm: '8px',
        DEFAULT: '12px',
        lg: '16px',
        xl: '20px',
        full: '9999px',
      },
      boxShadow: {
        sm: '0 2px 8px rgba(0,0,0,0.05)',
        md: '0 4px 16px rgba(0,0,0,0.06), 0 1px 4px rgba(0,0,0,0.03)',
        lg: '0 8px 32px rgba(0,0,0,0.08), 0 2px 8px rgba(0,0,0,0.04)',
        'inset-sm': 'inset 0 1px 2px rgba(0,0,0,0.04)',
      },
      spacing: {
        xs: '4px',
        sm: '8px',
        md: '16px',
        lg: '24px',
        xl: '32px',
        '2xl': '48px',
      },
      animation: {
        'fade-in': 'fadeIn 0.2s ease-out',
        'slide-up': 'slideUp 0.25s ease-out',
        'slide-in-left': 'slideInLeft 0.25s ease-out',
        pulse: 'pulse 2s cubic-bezier(0.4,0,0.6,1) infinite',
      },
      keyframes: {
        fadeIn: {
          from: { opacity: '0' },
          to: { opacity: '1' },
        },
        slideUp: {
          from: { opacity: '0', transform: 'translateY(8px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        slideInLeft: {
          from: { opacity: '0', transform: 'translateX(-8px)' },
          to: { opacity: '1', transform: 'translateX(0)' },
        },
      },
    },
  },
  plugins: [],
}