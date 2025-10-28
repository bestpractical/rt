// Kanban Board Drag and Drop
kanbanBoard = {
    draggedCard: null,

    dragstart: function(e) {
        kanbanBoard.draggedCard = this;
        this.classList.add('dragging');
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', this.dataset.ticketId);
    },

    dragend: function(e) {
        this.classList.remove('dragging');
        kanbanBoard.draggedCard = null;
        document.querySelectorAll('.kanban-column-cards').forEach(col => {
            col.classList.remove('drag-over');
        });
    },

    dragover: function(e) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
    },

    dragenter: function(e) {
        this.classList.add('drag-over');
    },

    dragleave: function(e) {
        if (e.target === this) {
            this.classList.remove('drag-over');
        }
    },

    drop: function(e) {
        e.stopPropagation();
        e.preventDefault();

        this.classList.remove('drag-over');

        const draggedCard = kanbanBoard.draggedCard;
        if (draggedCard) {
            const ticketId = draggedCard.dataset.ticketId;
            const currentValue = draggedCard.dataset.currentValue;
            const newValue = this.dataset.columnValue;

            const board = document.querySelector('.kanban-board');
            const kanbanField = board ? board.dataset.kanbanField : 'Status';
            const swimlaneField = board ? board.dataset.swimlaneField : null;

            const updates = {};

            if (currentValue !== newValue) {
                updates[kanbanField] = newValue;
            }

            if (swimlaneField) {
                const draggedFrom = draggedCard.closest('.kanban-column-cards');
                const currentSwimlane = draggedFrom ? draggedFrom.dataset.swimlaneValue : null;
                const targetSwimlane = this.dataset.swimlaneValue;

                if (currentSwimlane !== targetSwimlane) {
                    updates[swimlaneField] = targetSwimlane;
                }
            }

            if (Object.keys(updates).length > 0) {
                kanbanBoard.updateTicket(ticketId, updates, draggedCard, this);
            }
        }
    },

    registerDrag: function(card) {
        for (let event of ['dragstart', 'dragend']) {
            card.addEventListener(event, kanbanBoard[event]);
        }
    },

    registerDrop: function(column) {
        for (let event of ['dragover', 'dragenter', 'dragleave', 'drop']) {
            column.addEventListener(event, kanbanBoard[event]);
        }
    },

    updateTicket: function(ticketId, updates, cardElement, targetColumn) {
        cardElement.style.opacity = '0.5';
        cardElement.style.pointerEvents = 'none';

        const formData = new FormData();
        formData.append('id', ticketId);

        for (const [field, value] of Object.entries(updates)) {
            formData.append(field, value);
        }

        fetch(RT.Config.WebPath + '/Helpers/TicketUpdate', {
            method: 'POST',
            body: formData,
            headers: {
                'X-Requested-With': 'XMLHttpRequest'
            }
        })
        .then(response => response.json())
        .then(data => {
            if (updates[document.querySelector('.kanban-board').dataset.kanbanField]) {
                cardElement.dataset.currentValue = updates[document.querySelector('.kanban-board').dataset.kanbanField];
            }

            cardElement.style.opacity = '1';
            cardElement.style.pointerEvents = 'auto';

            targetColumn.appendChild(cardElement);

            kanbanBoard.updateColumnCounts();

            if (data.actions && data.actions.length > 0) {
                data.actions.forEach(action => {
                    kanbanBoard.showMessage(action, 'success');
                });
            } else {
                const fieldsList = Object.keys(updates).join(', ');
                kanbanBoard.showMessage('Ticket #' + ticketId + ' updated: ' + fieldsList, 'success');
            }
        })
        .catch(error => {
            cardElement.style.opacity = '1';
            cardElement.style.pointerEvents = 'auto';
            kanbanBoard.showMessage('Failed to update ticket', 'error');
            console.error('Error updating ticket:', error);
        });
    },

    updateColumnCounts: function() {
        document.querySelectorAll('.kanban-column').forEach(column => {
            const count = column.querySelectorAll('.kanban-card').length;
            const badge = column.querySelector('.badge');
            if (badge) {
                badge.textContent = count;
            }
        });
    },

    showMessage: function(message, type) {
        if (window.jQuery && window.jQuery.jGrowl) {
            jQuery.jGrowl(message, {
                themeState: type === 'error' ? 'error' : 'success'
            });
        } else {
            alert(message);
        }
    },

    init: function() {
        const board = document.querySelector('.kanban-board');
        if (!board) {
            return false;
        }

        const cards = document.querySelectorAll('.kanban-card');
        const columns = document.querySelectorAll('.kanban-column-cards');

        console.log('Kanban init: found', cards.length, 'cards and', columns.length, 'columns');

        cards.forEach(card => {
            kanbanBoard.registerDrag(card);
        });

        columns.forEach(column => {
            kanbanBoard.registerDrop(column);
        });

        return true;
    },

    setupHTMXListener: function() {
        // Set up HTMX listener only once
        if (document.body && !kanbanBoard.htmxListenerAdded) {
            document.body.addEventListener('htmx:afterSwap', function(evt) {
                const target = evt.detail.target;
                if (target.classList && target.classList.contains('kanban-wrapper') ||
                    target.querySelector && target.querySelector('.kanban-wrapper')) {
                    setTimeout(kanbanBoard.init, 100);
                }
            });
            kanbanBoard.htmxListenerAdded = true;
        }
    },

    htmxListenerAdded: false
};

// Initialize on page load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        kanbanBoard.init();
        kanbanBoard.setupHTMXListener();
    });
} else {
    kanbanBoard.init();
    kanbanBoard.setupHTMXListener();
}
