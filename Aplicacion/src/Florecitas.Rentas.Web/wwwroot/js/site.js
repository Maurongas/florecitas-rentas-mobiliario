// Florecitas · utilidades de interfaz
(function () {
  'use strict';

  // ---- Tema claro / oscuro ----------------------------------------------
  const btnTema = document.getElementById('btnTema');
  function pintarIconoTema() {
    if (!btnTema) return;
    const oscuro = document.documentElement.getAttribute('data-bs-theme') === 'dark';
    btnTema.innerHTML = oscuro ? '<i class="bi bi-sun"></i>' : '<i class="bi bi-moon-stars"></i>';
  }
  if (btnTema) {
    pintarIconoTema();
    btnTema.addEventListener('click', function () {
      const nuevo = document.documentElement.getAttribute('data-bs-theme') === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-bs-theme', nuevo);
      try { localStorage.setItem('tema', nuevo); } catch (e) { /* almacenamiento no disponible */ }
      pintarIconoTema();
      document.dispatchEvent(new CustomEvent('tema-cambiado'));
    });
  }

  // ---- Menú lateral en móvil -------------------------------------------
  const sidebar = document.getElementById('sidebar');
  const backdrop = document.getElementById('sidebarBackdrop');
  const btnMenu = document.getElementById('btnMenu');
  function cerrarMenu() {
    sidebar && sidebar.classList.remove('open');
    backdrop && backdrop.classList.remove('show');
    btnMenu && btnMenu.setAttribute('aria-expanded', 'false');
  }
  if (btnMenu) {
    btnMenu.addEventListener('click', function () {
      sidebar.classList.add('open');
      backdrop.classList.add('show');
      btnMenu.setAttribute('aria-expanded', 'true');
    });
  }
  backdrop && backdrop.addEventListener('click', cerrarMenu);
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') cerrarMenu(); });

  // ---- Toasts: auto-ocultar los de éxito --------------------------------
  document.querySelectorAll('.toast.show').forEach(function (el) {
    bootstrap.Toast.getOrCreateInstance(el).show();
  });

  // ---- Confirmaciones para acciones destructivas ------------------------
  document.addEventListener('submit', function (e) {
    const form = e.target;
    const msg = form.getAttribute('data-confirmar');
    if (msg && !window.confirm(msg)) {
      e.preventDefault();
      return;
    }
    // Evitar doble envío: deshabilita el botón y muestra estado de carga
    if (!e.defaultPrevented && form.method.toLowerCase() === 'post') {
      const btn = e.submitter || form.querySelector('[type=submit]');
      if (btn && !btn.hasAttribute('data-sin-carga')) {
        setTimeout(function () {
          btn.disabled = true;
          btn.dataset.textoOriginal = btn.innerHTML;
          btn.innerHTML = '<span class="spinner-border spinner-border-sm" aria-hidden="true"></span> Procesando…';
        }, 0);
      }
    }
  });

  // ---- Filas de tabla navegables ---------------------------------------
  document.querySelectorAll('tr[data-href]').forEach(function (tr) {
    tr.classList.add('row-link');
    tr.addEventListener('click', function (e) {
      if (e.target.closest('a, button, form, input, select')) return;
      window.location.href = tr.getAttribute('data-href');
    });
  });

  // Formato de moneda reutilizable
  window.florecitas = {
    moneda: new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }),
    colores: function () {
      const s = getComputedStyle(document.documentElement);
      return {
        primary: s.getPropertyValue('--color-primary').trim(),
        accent: s.getPropertyValue('--color-accent').trim(),
        muted: s.getPropertyValue('--color-muted').trim(),
        border: s.getPropertyValue('--color-border').trim(),
        fg: s.getPropertyValue('--color-foreground').trim()
      };
    }
  };
})();
