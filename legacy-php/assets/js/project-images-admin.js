const uploadForm = document.querySelector('.admin-multi-upload');

if (uploadForm instanceof HTMLFormElement) {
    const fileInput = uploadForm.querySelector('input[type="file"]');
    const previews = uploadForm.querySelector('[data-upload-previews]');
    const progress = uploadForm.querySelector('.admin-upload-progress');
    const status = uploadForm.querySelector('.admin-upload-status');

    if (fileInput instanceof HTMLInputElement && previews instanceof HTMLElement) {
        fileInput.addEventListener('change', () => {
            previews.replaceChildren();
            const files = Array.from(fileInput.files || []);

            if (files.length > 30) {
                fileInput.setCustomValidity('Choose no more than 30 images per batch.');
                fileInput.reportValidity();
                fileInput.value = '';
                return;
            }

            fileInput.setCustomValidity('');
            files.forEach((file) => {
                if (!file.type.startsWith('image/')) {
                    return;
                }

                const card = document.createElement('figure');
                const image = document.createElement('img');
                const caption = document.createElement('figcaption');
                image.src = URL.createObjectURL(file);
                image.alt = '';
                caption.textContent = file.name;
                card.append(image, caption);
                previews.append(card);
            });
        });

        uploadForm.addEventListener('submit', (event) => {
            if (!uploadForm.reportValidity()) {
                return;
            }

            event.preventDefault();
            const xhr = new XMLHttpRequest();
            xhr.open('POST', uploadForm.action);
            xhr.upload.addEventListener('progress', (progressEvent) => {
                if (progress instanceof HTMLProgressElement && progressEvent.lengthComputable) {
                    progress.hidden = false;
                    progress.value = Math.round((progressEvent.loaded / progressEvent.total) * 100);
                    if (status instanceof HTMLElement) {
                        status.textContent = `Uploading images… ${progress.value}%`;
                    }
                }
            });
            xhr.addEventListener('load', () => {
                const responseDocument = new DOMParser().parseFromString(xhr.responseText, 'text/html');
                const errorNotice = responseDocument.querySelector('.admin-alert--error');
                if (errorNotice instanceof HTMLElement) {
                    const currentNotice = document.querySelector('.admin-alert--error');
                    if (currentNotice instanceof HTMLElement) {
                        currentNotice.replaceWith(errorNotice);
                    } else {
                        uploadForm.before(errorNotice);
                    }
                    if (status instanceof HTMLElement) {
                        status.textContent = 'Upload could not be completed.';
                    }
                } else if (xhr.status >= 200 && xhr.status < 400) {
                    window.location.assign(xhr.responseURL || window.location.href);
                } else if (status instanceof HTMLElement) {
                    status.textContent = 'The upload failed. Check file size limits and try again.';
                }
            });
            xhr.addEventListener('error', () => {
                if (status instanceof HTMLElement) {
                    status.textContent = 'The upload failed. Check your connection and try again.';
                }
            });
            xhr.send(new FormData(uploadForm));
            if (progress instanceof HTMLProgressElement) {
                progress.hidden = false;
                progress.value = 0;
            }
            if (status instanceof HTMLElement) {
                status.textContent = 'Preparing upload…';
            }
        });
    }
}

const imageList = document.querySelector('[data-sortable-images]');
const orderForm = document.querySelector('[data-order-form]');

if (imageList instanceof HTMLElement && orderForm instanceof HTMLFormElement) {
    let draggedImage = null;

    const imageCards = () => Array.from(imageList.querySelectorAll('[data-image-id]'));
    const moveImage = (card, direction) => {
        const cards = imageCards();
        const index = cards.indexOf(card);
        const next = cards[index + direction];
        if (!(next instanceof HTMLElement)) {
            return;
        }

        if (direction < 0) {
            imageList.insertBefore(card, next);
        } else {
            imageList.insertBefore(next, card);
        }
        orderForm.classList.add('is-dirty');
        imageCards().forEach((item, itemIndex) => {
            const number = item.querySelector('.admin-image-card__number');
            if (number instanceof HTMLElement) {
                number.textContent = String(itemIndex + 1);
            }
        });
    };

    imageList.addEventListener('click', (event) => {
        if (!(event.target instanceof Element)) {
            return;
        }
        const button = event.target.closest('[data-move-image]');
        const card = button?.closest('[data-image-id]');
        if (!(button instanceof HTMLButtonElement) || !(card instanceof HTMLElement)) {
            return;
        }
        moveImage(card, Number(button.dataset.moveImage));
    });

    imageList.addEventListener('dragstart', (event) => {
        if (!(event.target instanceof HTMLElement)) {
            return;
        }
        draggedImage = event.target.closest('[data-image-id]');
        if (draggedImage instanceof HTMLElement) {
            draggedImage.classList.add('is-dragging');
            event.dataTransfer?.setData('text/plain', draggedImage.dataset.imageId || '');
            if (event.dataTransfer) {
                event.dataTransfer.effectAllowed = 'move';
            }
        }
    });

    imageList.addEventListener('dragover', (event) => {
        if (!(draggedImage instanceof HTMLElement) || !(event.target instanceof Element)) {
            return;
        }
        const target = event.target.closest('[data-image-id]');
        if (!(target instanceof HTMLElement) || target === draggedImage) {
            return;
        }
        event.preventDefault();
        const bounds = target.getBoundingClientRect();
        const insertAfter = event.clientY > bounds.top + bounds.height / 2;
        imageList.insertBefore(draggedImage, insertAfter ? target.nextSibling : target);
        orderForm.classList.add('is-dirty');
    });

    imageList.addEventListener('dragend', () => {
        if (draggedImage instanceof HTMLElement) {
            draggedImage.classList.remove('is-dragging');
        }
        draggedImage = null;
        imageCards().forEach((item, itemIndex) => {
            const number = item.querySelector('.admin-image-card__number');
            if (number instanceof HTMLElement) {
                number.textContent = String(itemIndex + 1);
            }
        });
    });

    orderForm.addEventListener('submit', (event) => {
        const orderInput = orderForm.querySelector('input[name="order"]');
        if (!(orderInput instanceof HTMLInputElement)) {
            event.preventDefault();
            return;
        }
        orderInput.value = imageCards().map((card) => card.dataset.imageId || '').join(',');
        orderForm.classList.remove('is-dirty');
    });

    imageCards().forEach((card) => {
        card.addEventListener('dragstart', (event) => {
            if (event.target instanceof HTMLElement && event.target.closest('input, button, form')) {
                event.preventDefault();
            }
        });
    });
}
