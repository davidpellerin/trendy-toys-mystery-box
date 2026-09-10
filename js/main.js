/* ==========================================================================
   Trendy Toys Canada — page interactions
   Plain ES5+/ES2015 script, loaded with `defer`. No dependencies.

   Everything here is progressive enhancement: with JS disabled the page is
   still fully readable and every buy button still goes somewhere real.
   ========================================================================== */

(function () {
  'use strict';

  /* ------------------------------------------------------------------------
     CONFIG — the only block you need to edit after creating your Stripe links.

     Create a Payment Link per plan at https://dashboard.stripe.com/payment-links
     and paste the URLs below. Any key left as an empty string falls back to the
     href already in the HTML, so nothing ever dead-ends.
     ---------------------------------------------------------------------- */

  var STRIPE_LINKS = {
    quarterly:  'https://buy.stripe.com/test_28E14o29X9nC9eJ25k6wE0g',
    semiannual: 'https://buy.stripe.com/test_6oUdRa4i5eHW2QlbFU6wE0h',
    annual:     'https://buy.stripe.com/test_cNifZi8ylarG76B11g6wE0e'
  };

  var FALLBACK_URL = '#pricing';

  /* ------------------------------------------------------------------------
     Helpers
     ---------------------------------------------------------------------- */

  var $ = function (sel, root) { return (root || document).querySelector(sel); };
  var $$ = function (sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  };

  var prefersReducedMotion = window.matchMedia
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;

  /* ------------------------------------------------------------------------
     Stripe links
     ---------------------------------------------------------------------- */

  function initStripeLinks() {
    $$('[data-stripe]').forEach(function (el) {
      var key = el.getAttribute('data-stripe');
      var url = STRIPE_LINKS[key];

      if (url) {
        el.href = url;
      } else if (!el.getAttribute('href') || el.getAttribute('href') === '#') {
        // Belt and braces: never leave a buy button pointing at '#'.
        el.href = FALLBACK_URL;
      }

      if (el.hostname && el.hostname !== window.location.hostname) {
        el.rel = 'noopener';
      }
    });
  }

  /* ------------------------------------------------------------------------
     Promo bar — hidden by default in the HTML so it can't flash before we
     check whether it was already dismissed.
     ---------------------------------------------------------------------- */

  var PROMO_KEY = 'ttc:promo-dismissed';

  function initPromoBar() {
    var bar = $('#promo');
    var close = $('#promo-close');
    if (!bar || !close) return;

    var dismissed = false;
    try { dismissed = localStorage.getItem(PROMO_KEY) === '1'; } catch (e) { /* private mode */ }

    if (!dismissed) bar.hidden = false;

    close.addEventListener('click', function () {
      bar.hidden = true;
      try { localStorage.setItem(PROMO_KEY, '1'); } catch (e) { /* ignore */ }
    });
  }

  /* ------------------------------------------------------------------------
     Sticky header shadow
     ---------------------------------------------------------------------- */

  function initStickyNav() {
    var header = $('#site-header');
    if (!header) return;

    var ticking = false;
    function update() {
      header.classList.toggle('is-stuck', window.scrollY > 40);
      ticking = false;
    }

    window.addEventListener('scroll', function () {
      if (!ticking) {
        window.requestAnimationFrame(update);
        ticking = true;
      }
    }, { passive: true });

    update();
  }

  /* ------------------------------------------------------------------------
     Mobile menu
     ---------------------------------------------------------------------- */

  function initMobileMenu() {
    var toggle = $('#nav-toggle');
    var links = $('#nav-links');
    if (!toggle || !links) return;

    var mq = window.matchMedia('(max-width: 860px)');

    function setOpen(open) {
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
      links.classList.toggle('is-open', open);
    }

    // Above the mobile breakpoint the links are always visible via CSS, so the
    // toggle state just gets reset rather than driving visibility.
    function syncToBreakpoint() {
      if (!mq.matches) setOpen(false);
    }

    toggle.addEventListener('click', function () {
      setOpen(toggle.getAttribute('aria-expanded') !== 'true');
    });

    // Tapping a link navigates within the page — close behind it.
    links.addEventListener('click', function (e) {
      if (e.target.closest('a') && mq.matches) setOpen(false);
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
        setOpen(false);
        toggle.focus();
      }
    });

    if (mq.addEventListener) mq.addEventListener('change', syncToBreakpoint);
    else if (mq.addListener) mq.addListener(syncToBreakpoint);

    syncToBreakpoint();
  }

  /* ------------------------------------------------------------------------
     Carousel — the track is a native scroll-snap container, so this only adds
     buttons and dots on top of behaviour that already works by swiping.
     ---------------------------------------------------------------------- */

  function initCarousel() {
    var track = $('#carousel-track');
    var prev = $('#carousel-prev');
    var next = $('#carousel-next');
    var dots = $('#carousel-dots');
    if (!track || !prev || !next || !dots) return;

    var items = $$('.carousel__item', track);
    if (!items.length) return;

    function step() {
      // One "page" is however many whole cards currently fit in view.
      var itemWidth = items[0].getBoundingClientRect().width;
      var gap = parseFloat(getComputedStyle(track).columnGap) || 0;
      var perView = Math.max(1, Math.round(track.clientWidth / (itemWidth + gap)));
      return (itemWidth + gap) * perView;
    }

    function pageCount() {
      return Math.max(1, Math.ceil(track.scrollWidth / track.clientWidth));
    }

    function currentPage() {
      return Math.round(track.scrollLeft / track.clientWidth);
    }

    function buildDots() {
      dots.innerHTML = '';
      var total = pageCount();
      if (total < 2) return;

      for (var i = 0; i < total; i++) {
        var b = document.createElement('button');
        b.type = 'button';
        b.setAttribute('aria-label', 'Go to slide ' + (i + 1) + ' of ' + total);
        b.dataset.page = String(i);
        b.addEventListener('click', function (e) {
          var page = Number(e.currentTarget.dataset.page);
          track.scrollTo({ left: page * track.clientWidth, behavior: scrollBehavior() });
        });
        dots.appendChild(b);
      }
    }

    function scrollBehavior() {
      return prefersReducedMotion ? 'auto' : 'smooth';
    }

    function syncControls() {
      var maxScroll = track.scrollWidth - track.clientWidth;
      prev.disabled = track.scrollLeft <= 1;
      next.disabled = track.scrollLeft >= maxScroll - 1;

      var page = currentPage();
      $$('button', dots).forEach(function (dot, i) {
        if (i === page) dot.setAttribute('aria-current', 'true');
        else dot.removeAttribute('aria-current');
      });
    }

    prev.addEventListener('click', function () {
      track.scrollBy({ left: -step(), behavior: scrollBehavior() });
    });
    next.addEventListener('click', function () {
      track.scrollBy({ left: step(), behavior: scrollBehavior() });
    });

    var scrollTimer;
    track.addEventListener('scroll', function () {
      clearTimeout(scrollTimer);
      scrollTimer = setTimeout(syncControls, 80);
    }, { passive: true });

    var resizeTimer;
    window.addEventListener('resize', function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () {
        buildDots();
        syncControls();
      }, 150);
    });

    buildDots();
    syncControls();
  }

  /* ------------------------------------------------------------------------
     FAQ — <details> already works alone; this just closes the others.
     ---------------------------------------------------------------------- */

  function initFaq() {
    var list = $('#faq-list');
    if (!list) return;

    var items = $$('details', list);
    items.forEach(function (item) {
      item.addEventListener('toggle', function () {
        if (!item.open) return;
        items.forEach(function (other) {
          if (other !== item) other.open = false;
        });
      });
    });
  }

  /* ------------------------------------------------------------------------
     Newsletter — client-side validation only. Nothing is submitted until the
     form's action= points at a real endpoint.
     ---------------------------------------------------------------------- */

  function initNewsletterForm() {
    var form = $('#newsletter-form');
    var input = $('#news-email');
    var msg = $('#newsletter-msg');
    if (!form || !input || !msg) return;

    function say(text, state) {
      msg.textContent = text;
      msg.setAttribute('data-state', state);
    }

    form.addEventListener('submit', function (e) {
      var value = input.value.trim();

      if (!value) {
        e.preventDefault();
        say('Please enter your email address.', 'error');
        input.focus();
        return;
      }

      if (!input.checkValidity()) {
        e.preventDefault();
        say("That doesn't look like a valid email address.", 'error');
        input.focus();
        return;
      }

      // No endpoint configured yet — stop here rather than navigating to '#'.
      if (!form.getAttribute('action') || form.getAttribute('action') === '#') {
        e.preventDefault();
        say("Thanks! You're on the list. (Heads up: no email service is connected yet.)", 'ok');
        form.reset();
      }
    });

    input.addEventListener('input', function () {
      if (msg.textContent) say('', '');
    });
  }

  /* ------------------------------------------------------------------------
     Scroll reveal
     ---------------------------------------------------------------------- */

  function initScrollReveal() {
    var targets = $$('.reveal');
    if (!targets.length) return;

    // Bail out and leave everything visible if we can't animate it properly.
    if (prefersReducedMotion || !('IntersectionObserver' in window)) return;

    // Opt in to the hidden starting state only now that we know we can undo it.
    document.documentElement.classList.add('js-reveal');

    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-in');
          io.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -10% 0px', threshold: 0.05 });

    targets.forEach(function (el) { io.observe(el); });
  }

  /* ------------------------------------------------------------------------
     Floating mobile CTA — appears once the hero is out of view.
     ---------------------------------------------------------------------- */

  function initFloatingCta() {
    var cta = $('#floating-cta');
    var hero = $('#top');
    if (!cta || !hero) return;

    if (!('IntersectionObserver' in window)) return;

    var io = new IntersectionObserver(function (entries) {
      cta.classList.toggle('is-visible', !entries[0].isIntersecting);
    }, { threshold: 0 });

    io.observe(hero);
  }

  /* ------------------------------------------------------------------------
     Footer year
     ---------------------------------------------------------------------- */

  function initFooterYear() {
    var el = $('#year');
    if (el) el.textContent = String(new Date().getFullYear());
  }

  /* ------------------------------------------------------------------------
     Boot — each init is independent and guarded, so one failure can't take
     the rest of the page down with it.
     ---------------------------------------------------------------------- */

  [
    initStripeLinks,
    initPromoBar,
    initStickyNav,
    initMobileMenu,
    initCarousel,
    initFaq,
    initNewsletterForm,
    initScrollReveal,
    initFloatingCta,
    initFooterYear
  ].forEach(function (fn) {
    try { fn(); } catch (err) {
      if (window.console) console.error(fn.name + ' failed:', err);
    }
  });
})();
