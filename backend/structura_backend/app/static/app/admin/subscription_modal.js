(function () {
    function getCookie(name) {
        var cookieValue = null;
        if (document.cookie && document.cookie !== '') {
            var cookies = document.cookie.split(';');
            for (var i = 0; i < cookies.length; i += 1) {
                var cookie = cookies[i].trim();
                if (cookie.substring(0, name.length + 1) === name + '=') {
                    cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                    break;
                }
            }
        }
        return cookieValue;
    }

    var openButton = document.getElementById('open-subscription-modal-btn');
    var closeButton = document.getElementById('close-subscription-modal-btn');
    var cancelButton = document.getElementById('cancel-subscription-modal-btn');
    var backdrop = document.getElementById('subscription-modal-backdrop');
    var form = document.getElementById('subscription-activation-form');
    var errorBox = document.getElementById('subscription-modal-error');
    var startDateInput = form ? form.querySelector('input[name="subscription_start_date"]') : null;
    var yearsInput = form ? form.querySelector('input[name="subscription_years"]') : null;
    var endDatePreviewInput = form ? form.querySelector('input[name="subscription_end_date_preview"]') : null;

    if (!openButton || !backdrop || !form) {
        return;
    }

    function openModal() {
        backdrop.hidden = false;
    }

    function closeModal() {
        backdrop.hidden = true;
        if (errorBox) {
            errorBox.hidden = true;
            errorBox.textContent = '';
        }
    }

    function setError(message) {
        if (!errorBox) {
            return;
        }
        errorBox.textContent = message;
        errorBox.hidden = false;
    }

    function formatDate(dateObj) {
        var month = String(dateObj.getMonth() + 1).padStart(2, '0');
        var day = String(dateObj.getDate()).padStart(2, '0');
        return dateObj.getFullYear() + '-' + month + '-' + day;
    }

    function calculateEndDate(startDateText, yearsText) {
        if (!startDateText || !yearsText) {
            return '';
        }

        var years = parseInt(yearsText, 10);
        if (Number.isNaN(years) || years < 1) {
            return '';
        }

        var dateParts = startDateText.split('-');
        if (dateParts.length !== 3) {
            return '';
        }

        var year = parseInt(dateParts[0], 10);
        var month = parseInt(dateParts[1], 10);
        var day = parseInt(dateParts[2], 10);

        if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day)) {
            return '';
        }

        var endDate = new Date(year + years, month - 1, day);

        // If rollover happens (e.g., Feb 29 to non-leap year), cap to the month's last valid day.
        if (endDate.getMonth() !== month - 1 || endDate.getDate() !== day) {
            endDate = new Date(year + years, month, 0);
        }

        return formatDate(endDate);
    }

    function refreshEndDatePreview() {
        if (!endDatePreviewInput || !startDateInput || !yearsInput) {
            return;
        }
        endDatePreviewInput.value = calculateEndDate(startDateInput.value, yearsInput.value);
    }

    openButton.addEventListener('click', openModal);

    if (startDateInput) {
        startDateInput.addEventListener('change', refreshEndDatePreview);
        startDateInput.addEventListener('input', refreshEndDatePreview);
    }

    if (yearsInput) {
        yearsInput.addEventListener('change', refreshEndDatePreview);
        yearsInput.addEventListener('input', refreshEndDatePreview);
    }

    if (closeButton) {
        closeButton.addEventListener('click', closeModal);
    }

    if (cancelButton) {
        cancelButton.addEventListener('click', closeModal);
    }

    backdrop.addEventListener('click', function (event) {
        if (event.target === backdrop) {
            closeModal();
        }
    });

    form.addEventListener('submit', function (event) {
        event.preventDefault();

        refreshEndDatePreview();

        var formData = new FormData(form);

        fetch(form.dataset.activateUrl, {
            method: 'POST',
            headers: {
                'X-CSRFToken': getCookie('csrftoken') || '',
            },
            body: formData,
            credentials: 'same-origin',
        })
            .then(function (response) {
                return response.json().then(function (payload) {
                    return { status: response.status, payload: payload };
                });
            })
            .then(function (result) {
                if (result.status >= 200 && result.status < 300 && result.payload.ok) {
                    window.location.reload();
                    return;
                }

                if (result.payload && result.payload.errors) {
                    var firstErrorKey = Object.keys(result.payload.errors)[0];
                    if (firstErrorKey && result.payload.errors[firstErrorKey].length) {
                        setError(result.payload.errors[firstErrorKey][0]);
                        return;
                    }
                }

                setError((result.payload && result.payload.message) || 'Unable to activate subscription.');
            })
            .catch(function () {
                setError('Network error. Please try again.');
            });
    });
})();
