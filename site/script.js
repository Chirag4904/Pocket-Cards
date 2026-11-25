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

const parallaxPreference = window.matchMedia(
  '(prefers-reduced-motion: no-preference) and (hover: hover) and (pointer: fine)',
);

for (const scene of document.querySelectorAll('[data-parallax-scene]')) {
  const layers = [...scene.querySelectorAll('[data-pointer-depth]')].map(layer => ({
    layer,
    depth: Number(layer.dataset.pointerDepth),
  })).filter(({ depth }) => Number.isFinite(depth));
  let animationFrame;
  let isEnabled = false;

  const reset = () => {
    for (const { layer } of layers) {
      layer.style.setProperty('--pointer-x', '0px');
      layer.style.setProperty('--pointer-y', '0px');
    }
  };

  const updateLayers = ({ clientX, clientY }) => {
    const bounds = scene.getBoundingClientRect();
    const pointerX = ((clientX - bounds.left) / bounds.width - 0.5) * 2;
    const pointerY = ((clientY - bounds.top) / bounds.height - 0.5) * 2;

    for (const { layer, depth } of layers) {
      layer.style.setProperty('--pointer-x', `${pointerX * depth}px`);
      layer.style.setProperty('--pointer-y', `${pointerY * depth}px`);
    }
  };

  const onPointerMove = event => {
    if (event.pointerType === 'touch') return;

    cancelAnimationFrame(animationFrame);
    animationFrame = requestAnimationFrame(() => updateLayers(event));
  };

  const onPointerLeave = () => {
    cancelAnimationFrame(animationFrame);
    reset();
  };

  const setEnabled = enabled => {
    if (enabled === isEnabled) return;

    isEnabled = enabled;
    if (enabled) {
      scene.addEventListener('pointermove', onPointerMove, { passive: true });
      scene.addEventListener('pointerleave', onPointerLeave, { passive: true });
      return;
    }

    scene.removeEventListener('pointermove', onPointerMove);
    scene.removeEventListener('pointerleave', onPointerLeave);
    cancelAnimationFrame(animationFrame);
    reset();
  };

  parallaxPreference.addEventListener('change', event => setEnabled(event.matches));
  setEnabled(parallaxPreference.matches);
}
