{{flutter_js}}
{{flutter_build_config}}

function removeSplashScreen() {
  const splash = document.getElementById('splash');
  if (!splash) return;
  splash.classList.add('splash--removed');
  splash.addEventListener('transitionend', () => splash.remove(), { once: true });
}

window.addEventListener('flutter-first-frame', removeSplashScreen);

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
