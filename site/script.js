const swatches = [...document.querySelectorAll('.swatch')];
const sample = document.querySelector('#sample-card');
const label = document.querySelector('#skin-label');

for (const swatch of swatches) {
  swatch.addEventListener('click', () => {
    for (const button of swatches) {
      const active = button === swatch;
      button.setAttribute('aria-pressed', String(active));
      button.classList.toggle('is-active', active);
    }

    const { skin, label: skinName } = swatch.dataset;
    sample.src = `assets/${skin}.webp`;
    sample.alt = `Sample card with the ${skinName} skin`;
    label.textContent = `Skin · ${skinName}`;

    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      sample.getAnimations().forEach(animation => animation.cancel());
      sample.animate(
        [{ opacity: 0.65, translate: '0 7px' }, { opacity: 1, translate: '0 0' }],
        { duration: 230, easing: 'ease-out' },
      );
    }
  });
}
