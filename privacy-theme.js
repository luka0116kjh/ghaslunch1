(function () {
    try {
        const getThemeCookie = () => document.cookie
            .split('; ')
            .find((row) => row.startsWith('theme='))
            ?.split('=')[1];
        const nativeTheme = (window.GHASAndroidApp || window.GHASAndroidNotifications)?.getTheme?.();
        const savedTheme = localStorage.getItem('theme') || nativeTheme || getThemeCookie();

        if (savedTheme === 'dark') {
            document.documentElement.classList.add('dark-theme');
        } else if (savedTheme === 'light') {
            document.documentElement.classList.add('light-theme');
        }
    } catch (error) {
        console.warn('Theme preference read failed:', error);
    }
}());
