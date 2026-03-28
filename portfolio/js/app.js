(function () {

    // ---- Theme Toggle ----
    var themeBtn = document.getElementById('themeToggle');
    var savedTheme = localStorage.getItem('theme');

    if (savedTheme === 'light') {
        document.body.classList.add('light');
    }

    themeBtn.addEventListener('click', function () {
        document.body.classList.toggle('light');
        localStorage.setItem('theme', document.body.classList.contains('light') ? 'light' : 'dark');
    });


    // ---- Language Switching ----
    var translations = {
        nav_about: { en: 'about', tr: 'hakkımda', ar: 'عني' },
        nav_portfolio: { en: 'projects', tr: 'projeler', ar: 'مشاريع' },
        nav_publications: { en: 'publications', tr: 'yayınlar', ar: 'منشورات' },
        nav_contact: { en: 'contact', tr: 'iletişim', ar: 'تواصل' },

        hero_left_title: { en: 'engineer', tr: 'mühendis', ar: 'مهندس' },
        hero_left_sub: {
            en: '<strong>Senior Backend Developer</strong> & <strong>DevOps Engineer</strong> who builds reliable, <strong>AWS cloud-native</strong> systems at scale.',
            tr: '<strong>Kıdemli Backend Geliştirici</strong> & <strong>DevOps Mühendisi</strong> olarak güvenilir, <strong>AWS bulut tabanlı</strong> sistemler inşa ediyorum.',
            ar: '<strong>مطور خلفي أول</strong> و <strong>مهندس DevOps</strong> يبني أنظمة <strong>AWS سحابية</strong> موثوقة وقابلة للتوسع.'
        },
        hero_left_badge: {
            en: 'Available for remote work & volunteer projects',
            tr: 'Uzaktan çalışma ve gönüllü projeler için müsait',
            ar: 'متاح للعمل عن بُعد والمشاريع التطوعية'
        },
        hero_right_sub: {
            en: '<strong>Senior Full Stack Developer</strong>, <strong>Flutter Developer</strong> & <strong>Vibe Coder</strong> who ships elegant <strong>mobile apps</strong> from idea to production.',
            tr: '<strong>Kıdemli Full Stack Geliştirici</strong>, <strong>Flutter Developer</strong> & <strong>Vibe Coder</strong> olarak zarif <strong>mobil uygulamalar</strong> geliştiriyorum.',
            ar: '<strong>مطور Full Stack أول</strong> و <strong>مطور Flutter</strong> و <strong>Vibe Coder</strong> يطور <strong>تطبيقات جوال</strong> أنيقة من الفكرة إلى الإنتاج.'
        },
        hero_right_badge: {
            en: 'Open to collaboration & opportunities',
            tr: 'İş birliği ve fırsatlara açık',
            ar: 'منفتح على التعاون والفرص'
        },

        section_about: { en: 'A few things about me', tr: 'Hakkımda birkaç bilgi', ar: 'بعض المعلومات عني' },
        section_work: { en: 'Some of my latest work', tr: 'Son çalışmalarımdan bazıları', ar: 'بعض أحدث أعمالي' },
        section_contact: { en: 'Get in touch', tr: 'İletişime geçin', ar: 'تواصل معي' },

        card_backend: { en: 'Backend & Cloud', tr: 'Backend & Cloud', ar: 'Backend & Cloud' },
        card_backend_sub: { en: 'Python, PHP, ASP.NET, AWS, Docker', tr: 'Python, PHP, ASP.NET, AWS, Docker', ar: 'Python, PHP, ASP.NET, AWS, Docker' },
        card_fullstack: { en: 'Full Stack', tr: 'Full Stack', ar: 'Full Stack' },
        card_fullstack_sub: { en: 'End-to-end from database to UI', tr: 'Veritabanından arayüze uçtan uca', ar: 'من قاعدة البيانات إلى الواجهة' },
        card_mobile: { en: 'Mobile & Flutter', tr: 'Mobil & Flutter', ar: 'موبايل & Flutter' },
        card_mobile_sub: { en: 'Cross-platform apps, native feel', tr: 'Çapraz platform uygulamalar', ar: 'تطبيقات متعددة المنصات' },
        card_uni: { en: 'Sharif University', tr: 'Sharif Üniversitesi', ar: 'جامعة شريف' },
        card_uni_sub: { en: 'B.Sc. Computer Engineering, GPA 17.54/20', tr: 'Bilgisayar Müh. Lisans, GPA 17.54/20', ar: 'بكالوريوس هندسة حاسوب، معدل 17.54/20' },
        card_devops: { en: 'DevOps & CI/CD', tr: 'DevOps & CI/CD', ar: 'DevOps & CI/CD' },
        card_devops_sub: { en: 'Docker, pipelines, infrastructure as code', tr: 'Docker, pipeline\'lar, kod olarak altyapı', ar: 'Docker، أنابيب، البنية التحتية ككود' },
        card_vibe: { en: 'Vibe Coding & AI', tr: 'Vibe Coding & AI', ar: 'Vibe Coding & AI' },
        card_vibe_sub: { en: 'AI-assisted dev, rapid prototyping', tr: 'AI destekli geliştirme, hızlı prototipleme', ar: 'تطوير بمساعدة الذكاء الاصطناعي' },

        card_mafia: { en: 'Mafia Party Game', tr: 'Mafia Parti Oyunu', ar: 'لعبة مافيا' },
        card_mafia_sub: { en: 'Real-time multiplayer web app', tr: 'Gerçek zamanlı çok oyunculu web uygulaması', ar: 'تطبيق ويب متعدد اللاعبين' },
        card_hdesk: { en: 'HDesk Ticketing', tr: 'HDesk Bilet Sistemi', ar: 'نظام تذاكر HDesk' },
        card_hdesk_sub: { en: 'Help desk & support platform', tr: 'Yardım masası ve destek platformu', ar: 'منصة دعم فني' },
        card_shop: { en: 'Online Shop', tr: 'Online Mağaza', ar: 'متجر إلكتروني' },
        card_shop_sub: { en: 'E-commerce storefront', tr: 'E-ticaret mağazası', ar: 'واجهة تجارة إلكترونية' },
        card_chat: { en: 'Chat Program', tr: 'Sohbet Programı', ar: 'برنامج محادثة' },
        card_chat_sub: { en: 'Real-time messaging with file sharing', tr: 'Dosya paylaşımlı mesajlaşma', ar: 'مراسلة فورية مع مشاركة ملفات' },
        card_zero: { en: 'Zero Trust Security', tr: 'Zero Trust Güvenlik', ar: 'أمان Zero Trust' },
        card_zero_sub: { en: 'B.Sc. thesis — network security research', tr: 'Lisans tezi — ağ güvenliği araştırması', ar: 'مشروع تخرج — بحث أمن الشبكات' },
        card_cacti: { en: 'Cacti Menu', tr: 'Cacti Menü', ar: 'قائمة Cacti' },
        card_cacti_sub: { en: 'Restaurant digital menu system', tr: 'Restoran dijital menü sistemi', ar: 'نظام قائمة رقمية للمطاعم' },

        contact_form_title: { en: 'Send me a message', tr: 'Bana mesaj gönderin', ar: 'أرسل لي رسالة' },
        contact_name: { en: 'Name', tr: 'İsim', ar: 'الاسم' },
        contact_email: { en: 'Email', tr: 'E-posta', ar: 'البريد الإلكتروني' },
        contact_subject: { en: 'Subject', tr: 'Konu', ar: 'الموضوع' },
        contact_message: { en: 'Message', tr: 'Mesaj', ar: 'الرسالة' },
        contact_name_ph: { en: 'Your name', tr: 'Adınız', ar: 'اسمك' },
        contact_email_ph: { en: 'your@email.com', tr: 'email@adresiniz.com', ar: 'بريدك@الإلكتروني.com' },
        contact_subject_ph: { en: "What's this about?", tr: 'Konu nedir?', ar: 'ما الموضوع؟' },
        contact_message_ph: { en: 'Write your message here...', tr: 'Mesajınızı buraya yazın...', ar: 'اكتب رسالتك هنا...' },
        contact_send: { en: 'Send Message', tr: 'Mesaj Gönder', ar: 'إرسال' },
        contact_or: { en: 'Or find me here', tr: 'Veya beni burada bulun', ar: 'أو تجدني هنا' },
        contact_linkedin: { en: "Let's connect", tr: 'Bağlanalım', ar: 'لنتواصل' },
        contact_github: { en: 'See my code', tr: 'Kodlarımı gör', ar: 'شاهد أكوادي' },
        contact_remote: {
            en: 'Available for <strong>remote work</strong> worldwide and eager to contribute to <strong>volunteer & open-source projects</strong>.',
            tr: 'Dünya genelinde <strong>uzaktan çalışmaya</strong> müsait ve <strong>gönüllü & açık kaynak projelere</strong> katkıda bulunmaya istekli.',
            ar: 'متاح <strong>للعمل عن بُعد</strong> حول العالم ومتحمس للمساهمة في <strong>المشاريع التطوعية والمفتوحة المصدر</strong>.'
        },

        footer_copy: { en: '© 2026 Shahab Rashidian Dezfuly', tr: '© 2026 Shahab Rashidian Dezfuly', ar: '© 2026 شهاب رشيديان دزفولي' }
    };

    var langBtns = document.querySelectorAll('.lang-btn');
    var savedLang = localStorage.getItem('lang') || 'en';

    function setLang(lang) {
        // Update all translatable elements
        var els = document.querySelectorAll('[data-i18n]');
        els.forEach(function (el) {
            var key = el.getAttribute('data-i18n');
            if (translations[key] && translations[key][lang]) {
                if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                    el.placeholder = translations[key][lang];
                } else {
                    el.innerHTML = translations[key][lang];
                }
            }
        });

        // Update active button
        langBtns.forEach(function (btn) {
            btn.classList.toggle('lang-btn--active', btn.dataset.lang === lang);
        });

        // RTL for Arabic
        document.body.classList.toggle('rtl', lang === 'ar');

        localStorage.setItem('lang', lang);
    }

    langBtns.forEach(function (btn) {
        btn.addEventListener('click', function () {
            setLang(this.dataset.lang);
        });
    });

    // Apply saved language
    setLang(savedLang);


    // ---- Mobile nav ----
    var toggle = document.getElementById('navToggle');
    var nav = document.getElementById('nav');

    toggle.addEventListener('click', function () {
        toggle.classList.toggle('nav-toggle--open');
        nav.classList.toggle('nav--open');
    });

    var links = nav.querySelectorAll('.nav__link');
    for (var i = 0; i < links.length; i++) {
        links[i].addEventListener('click', function () {
            toggle.classList.remove('nav-toggle--open');
            nav.classList.remove('nav--open');
        });
    }


    // ---- Smooth scroll (only for same-page anchors) ----
    var anchors = document.querySelectorAll('a[href^="#"]');
    for (var j = 0; j < anchors.length; j++) {
        anchors[j].addEventListener('click', function (e) {
            var href = this.getAttribute('href');
            if (href === '#top') {
                e.preventDefault();
                window.scrollTo({ top: 0, behavior: 'smooth' });
                return;
            }
            var target = document.querySelector(href);
            if (target) {
                e.preventDefault();
                window.scrollTo({ top: target.offsetTop - 72, behavior: 'smooth' });
            }
        });
    }


    // ---- Card reveal on scroll ----
    var cards = document.querySelectorAll('.card');
    var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
            if (entry.isIntersecting) {
                entry.target.classList.add('is-visible');
            }
        });
    }, { threshold: 0.1, rootMargin: '0px 0px -30px 0px' });

    for (var k = 0; k < cards.length; k++) {
        observer.observe(cards[k]);
    }

})();
