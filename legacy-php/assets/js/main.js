const initialContentVersion = document.body.dataset.contentVersion || '';

if (/^[a-f0-9]{64}$/.test(initialContentVersion)) {
    let checkingContentVersion = false;
    let hasUnsavedFormChanges = false;
    let hasReportedVersionError = false;

    document.querySelectorAll('form').forEach((form) => {
        form.addEventListener('input', () => { hasUnsavedFormChanges = true; });
        form.addEventListener('change', () => { hasUnsavedFormChanges = true; });
    });

    const showContentUpdateNotice = () => {
        if (document.querySelector('.site-update-notice')) {
            return;
        }

        const notice = document.createElement('aside');
        notice.className = 'site-update-notice';
        notice.setAttribute('role', 'status');

        const message = document.createElement('span');
        message.textContent = 'The website has been updated. Refresh to see the latest content.';

        const refreshButton = document.createElement('button');
        refreshButton.className = 'button button--primary';
        refreshButton.type = 'button';
        refreshButton.textContent = 'Refresh';
        refreshButton.addEventListener('click', () => window.location.reload());

        notice.append(message, refreshButton);
        document.body.append(notice);
    };

    window.setInterval(async () => {
        if (checkingContentVersion || document.visibilityState !== 'visible') {
            return;
        }

        checkingContentVersion = true;
        try {
            const response = await fetch('/content-version.php', {
                cache: 'no-store',
                headers: { Accept: 'application/json' },
            });
            if (!response.ok) {
                throw new Error(`Content version check failed with HTTP ${response.status}.`);
            }

            const result = await response.json();
            if (typeof result.version !== 'string' || !/^[a-f0-9]{64}$/.test(result.version)) {
                throw new Error('Content version check returned an invalid response.');
            }

            hasReportedVersionError = false;
            if (result.version !== initialContentVersion) {
                if (hasUnsavedFormChanges) {
                    showContentUpdateNotice();
                } else {
                    window.location.reload();
                }
            }
        } catch (error) {
            if (!hasReportedVersionError) {
                console.error('Unable to check for website updates.', error);
                hasReportedVersionError = true;
            }
        } finally {
            checkingContentVersion = false;
        }
    }, 60000);
}

const menuButton = document.querySelector('.site-nav__toggle');
const navigation = document.querySelector('#primary-navigation');

if (menuButton instanceof HTMLButtonElement && navigation instanceof HTMLElement) {
    const closeMenu = () => {
        menuButton.setAttribute('aria-expanded', 'false');
        navigation.classList.remove('is-open');
    };

    menuButton.addEventListener('click', () => {
        const isOpen = menuButton.getAttribute('aria-expanded') === 'true';
        menuButton.setAttribute('aria-expanded', String(!isOpen));
        navigation.classList.toggle('is-open', !isOpen);
    });

    document.addEventListener('click', (event) => {
        if (
            menuButton.getAttribute('aria-expanded') === 'true'
            && event.target instanceof Node
            && !navigation.contains(event.target)
            && !menuButton.contains(event.target)
        ) {
            closeMenu();
        }
    });

    navigation.querySelectorAll('a').forEach((link) => {
        link.addEventListener('click', closeMenu);
    });

    window.addEventListener('resize', () => {
        if (window.matchMedia('(min-width: 901px)').matches) {
            closeMenu();
        }
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && menuButton.getAttribute('aria-expanded') === 'true') {
            closeMenu();
            menuButton.focus();
        }
    });
}

const revealItems = document.querySelectorAll('.reveal');

if ('IntersectionObserver' in window && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const observer = new IntersectionObserver((entries, currentObserver) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add('is-visible');
                currentObserver.unobserve(entry.target);
            }
        });
    }, { threshold: 0.12 });

    revealItems.forEach((item) => observer.observe(item));
} else {
    revealItems.forEach((item) => item.classList.add('is-visible'));
}

const lightbox = document.querySelector('.lightbox');

if (lightbox instanceof HTMLDialogElement) {
    const lightboxImage = lightbox.querySelector('.lightbox__image');
    const stage = lightbox.querySelector('.lightbox__stage');
    const lightboxCaption = lightbox.querySelector('.lightbox__caption');
    const closeButton = lightbox.querySelector('.lightbox__close');
    const previousButton = lightbox.querySelector('.lightbox__previous');
    const nextButton = lightbox.querySelector('.lightbox__next');
    const fullscreenButton = lightbox.querySelector('.lightbox__fullscreen');
    const counter = lightbox.querySelector('.lightbox__counter');
    const featuredTrigger = document.querySelector('[data-gallery-featured]');
    const featuredImage = document.querySelector('[data-gallery-featured-image]');
    const featuredCaption = document.querySelector('[data-gallery-featured-caption]');
    const galleryCounter = document.querySelector('[data-gallery-counter]');
    const galleryCategory = document.querySelector('[data-gallery-category]');
    const galleryButtons = Array.from(document.querySelectorAll('.project-gallery__thumbnail'));
    let returnFocusTarget = null;
    let currentIndex = 0;

    const updateGalleryImage = (index) => {
        const trigger = galleryButtons[index];
        if (!(trigger instanceof HTMLElement)) {
            return;
        }

        currentIndex = index;
        if (featuredImage instanceof HTMLImageElement) {
            featuredImage.src = trigger.dataset.lightboxSrc || '';
            featuredImage.alt = trigger.dataset.lightboxAlt || '';
        }
        if (featuredCaption instanceof HTMLElement) {
            featuredCaption.textContent = trigger.dataset.lightboxCaption || '';
            featuredCaption.hidden = featuredCaption.textContent === '';
        }
        if (galleryCounter instanceof HTMLElement) {
            galleryCounter.textContent = `${index + 1} / ${galleryButtons.length}`;
        }
        if (galleryCategory instanceof HTMLElement) {
            galleryCategory.textContent = trigger.dataset.lightboxCategory || '';
        }
        galleryButtons.forEach((item, itemIndex) => {
            item.classList.toggle('is-current', itemIndex === index);
            item.setAttribute('aria-pressed', String(itemIndex === index));
        });
    };

    const updateLightbox = (index) => {
        if (!(lightboxImage instanceof HTMLImageElement) || !(lightboxCaption instanceof HTMLElement)) {
            return;
        }

        if (galleryButtons.length === 0) {
            return;
        }

        const wrappedIndex = (index + galleryButtons.length) % galleryButtons.length;
        const trigger = galleryButtons[wrappedIndex];
        if (!(trigger instanceof HTMLElement)) {
            return;
        }

        currentIndex = wrappedIndex;
        lightboxImage.classList.add('is-changing');
        window.setTimeout(() => {
            lightboxImage.src = trigger.dataset.lightboxSrc || '';
            lightboxImage.alt = trigger.dataset.lightboxAlt || '';
            lightboxCaption.textContent = trigger.dataset.lightboxCaption || '';
            lightboxCaption.hidden = lightboxCaption.textContent === '';
            lightboxImage.classList.remove('is-changing');
        }, 120);
        if (counter instanceof HTMLElement) {
            counter.textContent = `${wrappedIndex + 1} / ${galleryButtons.length}`;
        }
        updateGalleryImage(wrappedIndex);
    };

    if (featuredTrigger instanceof HTMLButtonElement) {
        featuredTrigger.addEventListener('click', () => {
            const index = Number(featuredTrigger.dataset.galleryIndex || 0);
            returnFocusTarget = featuredTrigger;
            updateLightbox(index);
            lightbox.showModal();
            closeButton instanceof HTMLButtonElement && closeButton.focus();
        });
    }

    document.querySelectorAll('.project-gallery__thumbnail').forEach((thumbnail, index) => {
        if (thumbnail instanceof HTMLButtonElement) {
            thumbnail.addEventListener('click', () => updateGalleryImage(index));
        }
    });

    previousButton?.addEventListener('click', () => updateLightbox(currentIndex - 1));
    nextButton?.addEventListener('click', () => updateLightbox(currentIndex + 1));

    let touchStartX = 0;
    if (stage instanceof HTMLElement) {
        stage.addEventListener('touchstart', (event) => { touchStartX = event.changedTouches[0]?.clientX || 0; }, { passive: true });
        stage.addEventListener('touchend', (event) => {
            const endX = event.changedTouches[0]?.clientX || 0;
            const delta = endX - touchStartX;
            if (Math.abs(delta) > 40) { updateLightbox(currentIndex + (delta < 0 ? 1 : -1)); }
        }, { passive: true });
    }
    closeButton?.addEventListener('click', () => lightbox.close());
    fullscreenButton?.addEventListener('click', async () => {
        if (document.fullscreenElement === lightbox) {
            await document.exitFullscreen();
            fullscreenButton.textContent = 'Full screen';
            fullscreenButton.setAttribute('aria-label', 'View image full screen');
        } else if (lightbox.requestFullscreen) {
            await lightbox.requestFullscreen();
            fullscreenButton.textContent = 'Exit full screen';
            fullscreenButton.setAttribute('aria-label', 'Exit full screen');
        }
    });

    lightbox.addEventListener('click', (event) => {
        if (event.target === lightbox) {
            lightbox.close();
        }
    });

    document.addEventListener('keydown', (event) => {
        if (!lightbox.open) {
            return;
        }
        if (event.key === 'Escape') {
            event.preventDefault();
            lightbox.close();
        } else if (event.key === 'ArrowLeft') {
            event.preventDefault();
            updateLightbox(currentIndex - 1);
        } else if (event.key === 'ArrowRight') {
            event.preventDefault();
            updateLightbox(currentIndex + 1);
        }
    });

    lightbox.addEventListener('close', () => {
        if (document.fullscreenElement === lightbox) {
            document.exitFullscreen();
        }
        if (lightboxImage instanceof HTMLImageElement) {
            lightboxImage.removeAttribute('src');
        }

        if (returnFocusTarget instanceof HTMLButtonElement) {
            returnFocusTarget.focus();
        }
    });
}

// Homepage hero slider (4 slides, fixed text/overlay)
(() => {
    const hero = document.querySelector('.hero--slider');
    if (!(hero instanceof HTMLElement)) return;
    const slides = Array.from(hero.querySelectorAll('[data-hero-slide]'));
    const indicators = Array.from(hero.querySelectorAll('[data-hero-indicator]'));
    const status = hero.querySelector('[data-hero-status]');
    if (slides.length < 2) return;

    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const delay = 2000;
    let currentSlide = 0;
    let timer = null;

    const preload = (index) => {
        const next = (index + 1) % slides.length;
        const img = slides[next];
        if (img instanceof HTMLImageElement) {
            const p = img.getAttribute('src');
            if (p) { const pre = new Image(); pre.decoding = 'async'; pre.src = p; }
        }
    };

    const goToSlide = (index, userInitiated = false) => {
        const next = (index + slides.length) % slides.length;
        if (next === currentSlide && userInitiated === false) return;
        slides[currentSlide]?.classList.remove('is-active');
        slides[next]?.classList.add('is-active');
        indicators.forEach((btn, i) => {
            const active = i === next;
            btn.classList.toggle('is-active', active);
            btn.setAttribute('aria-selected', active ? 'true' : 'false');
            btn.setAttribute('tabindex', active ? '0' : '-1');
        });
        currentSlide = next;
        if (status instanceof HTMLElement) status.textContent = `Showing hero image ${next + 1} of ${slides.length}`;
        const currentEl = document.getElementById('hero-current-slide');
        if (currentEl instanceof HTMLElement) currentEl.textContent = String(next + 1).padStart(2, '0');
        preload(next);
    };

    const stop = () => { if (timer) { clearInterval(timer); timer = null; } };
    const start = () => {
        stop();
        timer = window.setInterval(() => { nextSlide(); }, delay);
    };
    const nextSlide = () => goToSlide(currentSlide + 1);

    indicators.forEach((btn) => {
        btn.addEventListener('click', () => {
            const idx = Number(btn.getAttribute('data-hero-indicator') || 0);
            goToSlide(idx, true);
            start();
        });
        btn.addEventListener('keydown', (event) => {
            if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
                event.preventDefault();
                const dir = event.key === 'ArrowRight' ? 1 : -1;
                const idx = (currentSlide + dir + slides.length) % slides.length;
                goToSlide(idx, true);
                indicators[idx]?.focus();
                start();
            }
        });
    });

    // initial preload of next
    preload(0);
    start();

    document.addEventListener('visibilitychange', () => {
        if (document.hidden) stop(); else start();
    });
    reducedMotion.addEventListener?.('change', () => { /* CSS handles transition reduction */ });
})();

/* ==========================================================================
   Sticky Navigation on Scroll
   ========================================================================== */
(() => {
    const header = document.querySelector('#site-header');
    if (!(header instanceof HTMLElement)) return;

    let lastScrollY = window.scrollY;
    let ticking = false;

    const updateHeader = () => {
        const scrolled = window.scrollY > 60;
        header.classList.toggle('is-sticky', scrolled);

        if (scrolled && lastScrollY > window.scrollY) {
            header.style.transform = 'translateY(0)';
        } else if (!scrolled) {
            header.style.transform = 'translateY(0)';
        }

        lastScrollY = window.scrollY;
        ticking = false;
    };

    const requestTick = () => {
        if (!ticking) {
            window.requestAnimationFrame(updateHeader);
            ticking = true;
        }
    };

    window.addEventListener('scroll', requestTick, { passive: true });
})();

/* ==========================================================================
   Mobile Menu
   ========================================================================== */
(() => {
    const toggle = document.querySelector('.site-nav__toggle');
    const menu = document.querySelector('#mobile-menu');
    const overlay = document.querySelector('#mobile-menu-overlay');
    const closeBtn = document.querySelector('.mobile-menu__close');
    const links = document.querySelectorAll('.mobile-menu__list a');

    if (!(toggle instanceof HTMLElement) || !(menu instanceof HTMLElement) || !(overlay instanceof HTMLElement)) return;

    const openMenu = () => {
        toggle.setAttribute('aria-expanded', 'true');
        toggle.classList.add('is-active');
        menu.classList.add('is-open');
        overlay.classList.add('is-visible');
        document.body.classList.add('menu-open');
    };

    const closeMenu = () => {
        toggle.setAttribute('aria-expanded', 'false');
        toggle.classList.remove('is-active');
        menu.classList.remove('is-open');
        overlay.classList.remove('is-visible');
        document.body.classList.remove('menu-open');
    };

    toggle.addEventListener('click', () => {
        const isOpen = toggle.getAttribute('aria-expanded') === 'true';
        isOpen ? closeMenu() : openMenu();
    });

    closeBtn?.addEventListener('click', closeMenu);
    overlay?.addEventListener('click', closeMenu);

    links.forEach(link => link.addEventListener('click', closeMenu));

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
            closeMenu();
            toggle.focus();
        }
    });
})();

/* ==========================================================================
   Scroll Reveal Animations (IntersectionObserver)
   ========================================================================== */
(() => {
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)');
    const observerOptions = { threshold: 0.12, rootMargin: '0px 0px -80px 0px' };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('is-visible');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    document.querySelectorAll('.reveal').forEach(el => observer.observe(el));

    if (prefersReduced.matches) {
        document.querySelectorAll('.reveal').forEach(el => el.classList.add('is-visible'));
    }
})();

/* ==========================================================================
   Animated Counter
   ========================================================================== */
(() => {
    const counters = document.querySelectorAll('.counter[data-target]');
    if (counters.length === 0) return;

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (!entry.isIntersecting) return;
            const counter = entry.target;
            const target = parseInt(counter.getAttribute('data-target') || '0', 10);
            const duration = 2000;
            const start = performance.now();

            const update = (now) => {
                const elapsed = now - start;
                const progress = Math.min(elapsed / duration, 1);
                const ease = 1 - Math.pow(1 - progress, 3);
                const current = Math.floor(progress * target);
                counter.textContent = current.toLocaleString() + (counter.dataset.suffix || '+');
                if (progress < 1) {
                    requestAnimationFrame(update);
                }
            };

            requestAnimationFrame(update);
            observer.unobserve(counter);
        });
    }, { threshold: 0.5, rootMargin: '0px 0px -100px 0px' });

    counters.forEach(c => observer.observe(c));
})();

/* ==========================================================================
   Client Reviews / Testimonials Carousel
   Features: Next/Prev, Dots, Touch/Swipe, Keyboard Nav, Hover/Focus Pause, Auto-rotate
   ========================================================================== */
(() => {
    const carousel = document.querySelector('[data-testimonial-carousel]');
    if (!(carousel instanceof HTMLElement)) return;

    const track = carousel.querySelector('[data-testimonial-track]');
    const slides = Array.from(carousel.querySelectorAll('[data-testimonial-slide]'));
    const dots = Array.from(document.querySelectorAll('[data-testimonial-dot]'));
    const prevBtn = document.querySelector('[data-testimonial-prev]');
    const nextBtn = document.querySelector('[data-testimonial-next]');

    if (slides.length < 2) return;

    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const autoRotateDelay = 8000; // 8 seconds per slide: ample time to comfortably read
    let currentIndex = 0;
    let timer = null;
    let isHovered = false;
    let isFocused = false;

    // Touch swipe variables
    let touchStartX = 0;
    let touchStartY = 0;
    let touchEndX = 0;
    let touchEndY = 0;

    const updateCarousel = (index, userInitiated = false) => {
        const next = (index + slides.length) % slides.length;
        if (next === currentIndex && !userInitiated) return;

        // Animate track
        if (track instanceof HTMLElement) {
            track.style.transform = `translateX(-${next * 100}%)`;
        }

        // Update slide classes and ARIA
        slides.forEach((slide, i) => {
            const isActive = i === next;
            slide.classList.toggle('is-active', isActive);
            slide.setAttribute('aria-hidden', isActive ? 'false' : 'true');
        });

        // Update pagination indicators
        dots.forEach((dot, i) => {
            const isActive = i === next;
            dot.classList.toggle('is-active', isActive);
            dot.setAttribute('aria-selected', isActive ? 'true' : 'false');
            dot.setAttribute('tabindex', isActive ? '0' : '-1');
        });

        currentIndex = next;
    };

    const nextSlide = () => updateCarousel(currentIndex + 1, true);
    const prevSlide = () => updateCarousel(currentIndex - 1, true);

    const stopTimer = () => {
        if (timer) {
            clearInterval(timer);
            timer = null;
        }
    };

    const startTimer = () => {
        stopTimer();
        if (reducedMotion.matches || isHovered || isFocused) return;
        timer = window.setInterval(nextSlide, autoRotateDelay);
    };

    // Controls listeners
    if (prevBtn instanceof HTMLElement) {
        prevBtn.addEventListener('click', () => {
            prevSlide();
            startTimer();
        });
    }

    if (nextBtn instanceof HTMLElement) {
        nextBtn.addEventListener('click', () => {
            nextSlide();
            startTimer();
        });
    }

    // Dots listeners
    dots.forEach((dot) => {
        dot.addEventListener('click', () => {
            const idx = Number(dot.getAttribute('data-testimonial-dot') || 0);
            updateCarousel(idx, true);
            startTimer();
        });

        dot.addEventListener('keydown', (event) => {
            if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
                event.preventDefault();
                const dir = event.key === 'ArrowRight' ? 1 : -1;
                const idx = (currentIndex + dir + slides.length) % slides.length;
                updateCarousel(idx, true);
                dots[idx]?.focus();
                startTimer();
            }
        });
    });

    // Keyboard navigation within carousel container
    carousel.addEventListener('keydown', (event) => {
        if (event.key === 'ArrowLeft') {
            event.preventDefault();
            prevSlide();
            startTimer();
        } else if (event.key === 'ArrowRight') {
            event.preventDefault();
            nextSlide();
            startTimer();
        }
    });

    // Pause on hover
    carousel.addEventListener('mouseenter', () => {
        isHovered = true;
        stopTimer();
    });

    carousel.addEventListener('mouseleave', () => {
        isHovered = false;
        startTimer();
    });

    // Pause on focus within (accessibility standard)
    carousel.addEventListener('focusin', () => {
        isFocused = true;
        stopTimer();
    });

    carousel.addEventListener('focusout', () => {
        isFocused = false;
        startTimer();
    });

    // Touch & Swipe gestures for mobile devices
    carousel.addEventListener('touchstart', (e) => {
        if (e.touches.length === 1) {
            touchStartX = e.touches[0].clientX;
            touchStartY = e.touches[0].clientY;
        }
    }, { passive: true });

    carousel.addEventListener('touchmove', (e) => {
        if (e.touches.length === 1) {
            touchEndX = e.touches[0].clientX;
            touchEndY = e.touches[0].clientY;
        }
    }, { passive: true });

    carousel.addEventListener('touchend', () => {
        const deltaX = touchEndX - touchStartX;
        const deltaY = touchEndY - touchStartY;

        // Ensure horizontal intent (horizontal distance exceeds vertical and passes 40px threshold)
        if (Math.abs(deltaX) > 40 && Math.abs(deltaX) > Math.abs(deltaY)) {
            if (deltaX < 0) {
                nextSlide();
            } else {
                prevSlide();
            }
            startTimer();
        }

        // Reset
        touchStartX = 0;
        touchStartY = 0;
        touchEndX = 0;
        touchEndY = 0;
    });

    // Stop auto-rotation when page is hidden
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
            stopTimer();
        } else {
            startTimer();
        }
    });

    // Handle prefers-reduced-motion changes
    reducedMotion.addEventListener?.('change', () => {
        if (reducedMotion.matches) {
            stopTimer();
        } else {
            startTimer();
        }
    });

    // Start initial rotation
    startTimer();
})();

