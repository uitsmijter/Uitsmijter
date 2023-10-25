// On Page Load
document.addEventListener("DOMContentLoaded", () => {
    // change the form submit to a button - because js is enabled
    let loginButton = document.getElementById("loginButton");
    let loginSpinner = document.getElementById("loginSpinner");
    loginButton.type = "button"
    loginButton.onclick = () => {
        let forms = document.forms
        for (let i = 0; i < forms.length; ++i) {
            let form = forms.item(i)
            if (form.action.endsWith("/login")) {
                loginSpinner.classList.remove('login-spinner-invisible');
                form.submit();
                // history back.. disable spinner after 5s
                setTimeout(() => {
                    loginSpinner.classList.add('login-spinner-invisible');
                }, 5000)
            }
        }
    }
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

