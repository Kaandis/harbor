(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const store = {
    get(key) { try { return localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch { /* private mode */ } },
  };

  // English lives in the HTML (what search engines index); Turkish is applied on top.
  const TR = {
    'nav.free': 'Ücretsiz',
    'nav.apps': 'Uygulamalar',
    'nav.faq': 'SSS',
    'hero.line1': 'Tüm Harbor uygulamaların,',
    'hero.line2': 'tek sakin bir yerde.',
    'hero.lead': 'Harbor her Harbor uygulamasını gösterir, birinin güncellemesi olduğunda söyler ve ayarlarını tek yerde tutar; böylece uygulamaların kendisi küçük kalabilir.',
    'hero.download': 'Ücretsiz indir',
    'hero.github': 'GitHub’da yıldızla',
    'mb.file': 'Dosya', 'mb.edit': 'Düzen', 'mb.view': 'Görüntü', 'mb.window': 'Pencere',
    'demo.hint': 'Bir uygulamanın sayfasını açmak için pencereye tıkla. Alttaki Dock’ta yalnızca Harbor uygulamaları var; her simge kendi sitesine götürür.',
    'how.title': 'Mağaza değil, bir liman.',
    'f1.t': 'Kuşbakışı bir liman', 'f1.d': 'Kurulu uygulamalar iskelelerinde, diğerleri demirde bekler. Birini kurduğunda indirme ilerledikçe limana girer.',
    'f2.t': 'Tek tıkla güncelleme', 'f2.d': 'Güncelle’ye bas; Harbor sürümü indirir, doğrular, yerine koyar ve uygulamayı yeniden açar. Sen basmadan hiçbir şey olmaz.',
    'f3.t': 'Ayarlar tek yerde', 'f3.d': 'Her uygulama ayarlarını tarif eder; Harbor onları çizer, uygulama değişikliği anında alır.',
    'f4.t': 'Temiz kaldırma', 'f4.d': 'Kaldır, bir uygulamayı ve Mac’inde tuttuğu her şeyi Çöp Sepeti’ne taşır: ayarlar, önbellekler, kayıtlar ve izinler.',
    'apps.title': 'Limandakiler',
    'apps.inlet': 'Çentiğin artık işe yarıyor.',
    'apps.ferry': 'Her pencere bir Tab uzağında.',
    'apps.stow': 'Daha sakin bir menü çubuğu.',
    'apps.next': 'Sıradaki gemi',
    'apps.nextD': 'Yolda.',
    'cta.title': 'Ücretsiz. Sakin. Senin.',
    'cta.lead': 'Hesap yok, takip yok, mağaza yok.',
    'cta.note': 'macOS 15 veya üstü. Zip’i aç, Harbor’ı Uygulamalar’a taşı; ilk seferde sağ tıklayıp Aç’ı seç.',
    'faq.title': 'Sorular',
    'q1.q': 'Inlet ya da Ferry için Harbor gerekli mi?', 'q1.a': 'Hayır. Her uygulama tek başına çalışır ve küçük bir Ayarlar penceresi tutar. Harbor onları yalnızca tek yerde toplar.',
    'q2.q': 'Güncellemeler nasıl çalışıyor?', 'q2.a': 'Güncelle’ye (ya da Tümünü Güncelle’ye) bas. Harbor uygulamanın sürümünü GitHub’dan indirir, SHA-256’sını katalogla karşılaştırır, açıksa uygulamayı kapatır, yerinde değiştirir ve yeniden açar. Sen düğmeye basmadan hiçbir şey kurulmaz.',
    'q3.q': 'Ayarlar uygulamalara nasıl ulaşıyor?', 'q3.a': 'Her uygulama ayarlarını tarif eden küçük bir dosyayla gelir. Harbor onu okur, kontrolleri çizer, seçimini o uygulamanın kendi tercihlerine yazar ve uygulamaya haber verir; uygulama da hemen uygular.',
    'q4.q': 'Harbor internete ne gönderiyor?', 'q4.a': 'Hiçbir şey. Son sürümleri öğrenmek için bu sitedeki herkese açık tek bir dosyayı, <code>catalog.json</code>’u okur (günde en fazla iki kez ya da Güncellemeleri Denetle’ye bastığında) ve bir sürümü yalnızca kurduğunda ya da güncellediğinde indirir.',
    'q5.q': 'macOS açılamıyor diyor.', 'q5.a': 'Sürümler henüz notarize edilmedi. Harbor’a sağ tıklayıp Aç’ı seç ya da şunu çalıştır: <code>xattr -dr com.apple.quarantine /Applications/Harbor.app</code>',
    'footer.license': 'MIT Lisansı',
    'footer.catalog': 'Katalog',
    'footer.disclaimer': 'Harbor bağımsız bir projedir; Apple Inc. ile bağlantılı değildir, Apple tarafından onaylanmamış veya desteklenmemiştir. Mac ve macOS, Apple Inc.’in ABD’de ve diğer ülkelerde tescilli ticari markalarıdır.',
  };

  const nodes = $$('[data-i18n]');
  const EN = Object.fromEntries(nodes.map((n) => [n.dataset.i18n, n.innerHTML]));
  const langButton = $('#lang');
  let lang = 'en';

  function setLanguage(next) {
    lang = next;
    nodes.forEach((n) => { n.innerHTML = (next === 'tr' ? TR : EN)[n.dataset.i18n] ?? EN[n.dataset.i18n]; });
    document.documentElement.lang = next;
    langButton.textContent = next === 'tr' ? 'EN' : 'TR';
    langButton.setAttribute('aria-label', next === 'tr' ? 'Switch to English' : 'Türkçeye geç');
    store.set('lang', next);
    tickClock();
  }

  // The Mac is built at 960×600 and scaled to fit.
  const frame = $('#macFrame');
  const mac = $('#mac');
  let k = 1;
  function fit() {
    const pad = parseFloat(getComputedStyle(frame).paddingLeft);
    k = (frame.clientWidth - pad * 2) / 960;
    mac.style.transform = `scale(${k})`;
    frame.style.height = `${600 * k + pad * 2}px`;
  }
  addEventListener('resize', fit);
  fit();

  const nav = $('#nav');
  const onScroll = () => nav.classList.toggle('scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  function tickClock() {
    const now = new Date();
    const locale = lang === 'tr' ? 'tr-TR' : 'en-US';
    $('#menuClock').textContent = `${now.toLocaleDateString(locale, { weekday: 'short' })} ${now.toLocaleTimeString(locale, { hour: 'numeric', minute: '2-digit' })}`;
  }
  setInterval(tickClock, 10_000);

  // The window flips between the harbour and an app's page, cross-fading.
  const SHOTS = ['assets/shots/shelf.png?v=2', 'assets/shots/ferry.png?v=2'];
  const ALTS = ['Harbor’s harbour, with Inlet sailing in to its berth beside Ferry', 'Ferry’s page in Harbor, with its settings'];
  let shotIndex = 0;
  const shot = $('#shot');
  $('#harborWindow').addEventListener('click', () => {
    shotIndex = (shotIndex + 1) % SHOTS.length;
    const swap = () => {
      shot.src = SHOTS[shotIndex];
      shot.alt = ALTS[shotIndex];
      shot.classList.remove('fading');
    };
    if (reduceMotion.matches) { swap(); return; }
    shot.classList.add('fading');
    setTimeout(swap, 200);
  });

  // The Harbor Dock: only Harbor apps, each linking to its site.
  const HARBOR = [
    { name: 'Inlet', url: 'https://kaandis.github.io/inlet/', icon: 'assets/inlet-icon.png?v=1' },
    { name: 'Ferry', url: 'https://kaandis.github.io/ferry/', icon: 'assets/ferry-icon.png?v=1' },
    { name: 'Stow', url: 'https://kaandis.github.io/stow/', icon: 'assets/stow-icon.png?v=1' },
    { name: 'Harbor', url: 'https://kaandis.github.io/harbor/', icon: 'assets/icon.png?v=3', running: true, self: true },
  ];
  const dock = $('#dock');
  const label = $('#dockLabel');
  dock.innerHTML = HARBOR.map((app) => `<a href="${app.url}" class="${app.running ? 'running' : ''}" aria-label="${app.name}"${app.self ? ' data-self' : ' target="_blank" rel="noopener"'}><img src="${app.icon}" alt="" width="52" height="52"></a>`).join('');
  $$('a', dock).forEach((a) => {
    a.addEventListener('pointerenter', () => {
      const box = a.getBoundingClientRect();
      const macBox = mac.getBoundingClientRect();
      label.textContent = a.getAttribute('aria-label');
      label.hidden = false;
      label.style.left = `${(box.left + box.width / 2 - macBox.left) / k}px`;
    });
    a.addEventListener('pointerleave', () => { label.hidden = true; });
    if (a.hasAttribute('data-self')) {
      a.addEventListener('click', (e) => {
        e.preventDefault();
        scrollTo({ top: 0, behavior: reduceMotion.matches ? 'auto' : 'smooth' });
      });
    }
  });

  const saved = store.get('lang');
  const initial = (saved === 'tr' || saved === 'en') ? saved : ((navigator.language || '').toLowerCase().startsWith('tr') ? 'tr' : 'en');
  setLanguage(initial);
  langButton.addEventListener('click', () => setLanguage(lang === 'tr' ? 'en' : 'tr'));
})();
