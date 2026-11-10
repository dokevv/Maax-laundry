// =====================================================================
// KONFIGURASI MAXX LAUNDRY
// firebaseConfig dari Firebase Console > Project settings > Your apps (maxx-web).
// Kode ini AMAN untuk publik (bukan password). Keamanan data diatur oleh
// aturan Firestore (firestore.rules) yang hanya mengizinkan email di bawah.
// =====================================================================
window.MAXX_CONFIG = {
  firebase: {
    apiKey: 'AIzaSyDhvZU6qoq5or1x4xiG-ar8v-SxgVZH64M',
    authDomain: 'maxxlaundry.firebaseapp.com',
    projectId: 'maxxlaundry',
    storageBucket: 'maxxlaundry.firebasestorage.app',
    messagingSenderId: '350741726117',
    appId: '1:350741726117:web:b28eee99d3d6bf09625e4c',
  },
  // Email akun Owner (akses penuh) dan akun Outlet (tablet kasir).
  ownerEmails: ['pings.hellokitty@gmail.com'],
  outletEmails: ['outlet@maxxlaundry.id'],
};
