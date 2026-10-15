// On Page Load
document.addEventListener("DOMContentLoaded", () => {
    // The login button stays a native submit button, so the browser submits the form
    // on a click as well as on Enter in any of the form fields.
    let loginButton = document.getElementById("loginButton");
    let loginSpinner = document.getElementById("loginSpinner");
    let loginForm = loginButton ? loginButton.form : null;
    if (!loginForm) {
        return;
    }

    let submitting = false;
    loginForm.addEventListener("submit", (event) => {
        // prevent double submits while the login is in progress
        if (submitting) {
            event.preventDefault();
            return;
        }
        submitting = true;
        if (loginSpinner) {
            loginSpinner.classList.remove('login-spinner-invisible');
        }
    });

    // history back restores the page from the cache: reset the spinner
    window.addEventListener("pageshow", (event) => {
        if (event.persisted) {
            submitting = false;
            if (loginSpinner) {
                loginSpinner.classList.add('login-spinner-invisible');
            }
        }
    });
});

// Clock
class SimpleClock {
    constructor(element) {
        this._currentTime = this.updateTime();
        setInterval(() => {
            this.element = element
            this._currentTime = this.updateTime();
        }, 10000);
    }

    updateTime() {
        let d = new Date()
        let hh = d.getHours() < 10 ? ('0' + d.getHours()) : d.getHours();
        let mm = d.getMinutes() < 10 ? ('0' + d.getMinutes()) : d.getMinutes();
        let timeString = `${hh}:${mm}`;
        let element = document.getElementById(this.element)
        if (element) {
            element.innerHTML = timeString
        }
        return timeString;
    }

    activate(id) {
        this.element = id
    }

    get currentTime() {
        return this._currentTime
    }
}

