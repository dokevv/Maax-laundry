// =====================================================================
// Backend Maxx Laundry: Firebase Auth + Cloud Firestore.
// Menyediakan API kecil (doc/collection/where/onSnapshot/set/delete)
// yang dipakai index.html, plus penyimpanan foto bukti di Firestore.
// =====================================================================
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword, signOut,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';
import {
  initializeFirestore, persistentLocalCache, persistentMultipleTabManager,
  doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, addDoc,
  onSnapshot, query, where, limit as fLimit, orderBy as fOrderBy, serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js';

const cfg = window.MAXX_CONFIG || {};
const app = initializeApp(cfg.firebase);
const auth = getAuth(app);
let fs;
try {
  // Cache lokal: aplikasi tetap bisa dipakai saat internet putus, lalu sinkron otomatis.
  fs = initializeFirestore(app, { localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }) });
} catch (e) {
  fs = initializeFirestore(app, {});
}

const mapErr = (e) => {
  const c = e && e.code ? String(e.code).replace('firestore/', '') : '';
  if (c === 'permission-denied' || c === 'unauthenticated') return { code: 'invalid_argument', message: 'Tidak punya izin' };
  if (c === 'resource-exhausted') return { code: 'quota_exceeded', message: e.message };
  if (c === 'invalid-argument') return { code: 'invalid_argument', message: e.message };
  return { code: 'unavailable', message: (e && e.message) || String(e) };
};
const emitWriteError = (e) => window.dispatchEvent(new CustomEvent('maxx-write-error', { detail: mapErr(e) }));

/* Tulis tanpa menunggu server terlalu lama: saat offline, data tersimpan lokal
   dan dikirim otomatis begitu internet kembali. Error izin dilaporkan lewat event. */
function softWrite(p) {
  let timedOut = false;
  p.catch((e) => { if (timedOut) emitWriteError(e); });
  return Promise.race([
    p.then(() => undefined, (e) => { throw mapErr(e); }),
    new Promise((r) => setTimeout(() => { timedOut = true; r(); }, 1500)),
  ]);
}

const wrapDoc = (s) => ({ id: s.id, exists: s.exists(), data: () => s.data(), metadata: s.metadata });
const wrapQuery = (s) => ({ docs: s.docs.map(wrapDoc), size: s.size, empty: s.empty, metadata: s.metadata, docChanges: () => [] });

function makeDoc(ref) {
  return {
    id: ref.id, path: ref.path,
    get: async () => wrapDoc(await getDoc(ref)),
    // _serverAt = jam server Google (tidak bisa diakali dengan mengubah jam tablet).
    set: (d) => softWrite(setDoc(ref, { ...d, _serverAt: serverTimestamp() })),
    update: (d) => softWrite(updateDoc(ref, d)),
    delete: () => softWrite(deleteDoc(ref)),
    onSnapshot: (next, err) => onSnapshot(ref, (s) => next(wrapDoc(s)), (e) => err && err(mapErr(e))),
    collection: (p) => makeQuery(collection(ref, p)),
  };
}
function makeQuery(colRef, cons = []) {
  const q = () => (cons.length ? query(colRef, ...cons) : colRef);
  return {
    path: colRef.path,
    where: (f, op, v) => makeQuery(colRef, [...cons, where(f, op, v)]),
    orderBy: (f, d) => makeQuery(colRef, [...cons, fOrderBy(f, d || 'asc')]),
    limit: (n) => makeQuery(colRef, [...cons, fLimit(n)]),
    get: async () => wrapQuery(await getDocs(q())),
    onSnapshot: (next, err) => onSnapshot(q(), (s) => next(wrapQuery(s)), (e) => err && err(mapErr(e))),
    doc: (id) => makeDoc(id ? doc(colRef, id) : doc(colRef)),
    add: async (d) => { const r = doc(colRef); await softWrite(setDoc(r, { ...d, _serverAt: serverTimestamp() })); return makeDoc(r); },
  };
}
const db = { doc: (p) => makeDoc(doc(fs, p)), collection: (p) => makeQuery(collection(fs, p)) };

/* Foto bukti: dikecilkan di aplikasi, lalu disimpan sebagai dokumen di koleksi "proofs". */
const blobToDataUrl = (blob) => new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = rej; r.readAsDataURL(blob); });
const assets = {
  upload: async (blob) => {
    const data = await blobToDataUrl(blob);
    if (data.length > 900000) throw { code: 'invalid_argument', message: 'Foto terlalu besar' };
    const ref = doc(collection(fs, 'proofs'));
    await softWrite(setDoc(ref, { data, createdAt: new Date().toISOString(), _serverAt: serverTimestamp() }));
    return { id: ref.id, url: '', sizeBytes: blob.size, contentType: blob.type };
  },
  get: async (id) => { const s = await getDoc(doc(fs, 'proofs', id)); return s.exists() ? s.data().data : ''; },
};

const lower = (a) => (a || []).map((x) => String(x).toLowerCase());
window.MaxxBackend = {
  db, assets,
  login: (email, pw) => signInWithEmailAndPassword(auth, email.trim(), pw),
  logout: () => signOut(auth),
  onUser: (cb) => onAuthStateChanged(auth, (u) => {
    if (!u) return cb(null);
    const email = String(u.email || '').toLowerCase();
    const role = lower(cfg.ownerEmails).includes(email) ? 'owner' : lower(cfg.outletEmails).includes(email) ? 'outlet' : 'none';
    cb({ email, role });
  }),
};
window.dispatchEvent(new Event('maxx-backend-ready'));
