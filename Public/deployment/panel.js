function connectWebSocket()
{
    socket = new WebSocket('wss://mottzi.de/admin/ws');
    
    socket.onmessage = (event) =>
    {
        console.log(`WebSocket message received: ${event.data}`)
                
        try
        {
            const data = JSON.parse(event.data)
            
            switch (data.type)
            {
                case 'creation':
                    console.log(`CREATION: ${data.type.creation.deployment}`)
                    
                    // create new row and add it to table
                    const tbody = document.querySelector('tbody');
                    const newRow = createDeploymentRow(data.type.creation.deployment);
                    tbody.insertBefore(newRow, tbody.firstChild);
                    
                    break
                    
                case 'update':
                    console.log(`UPDATE: ${data.deployment}`)
                    break
            }
        }
        catch (error)
        {
            console.error('Failed to process message:', error)
        }
    }
    
    socket.onclose = () =>
    {
        console.log('WebSocket closed: Reconnecting ...')
        setTimeout(connectWebSocket, 5000); // Reconnect
    }
}

function getStatusBadge(status)
{
    const classes = {
        success: 'bg-green-100 text-green-800 dark:bg-green-800/30 dark:text-green-200',
        failure: 'bg-red-100 text-red-800 dark:bg-red-800/30 dark:text-red-200',
        default: 'bg-blue-100 text-blue-800 dark:bg-blue-800/30 dark:text-blue-200'
    };
    
    const badgeClass = classes[status] || classes.default;
    
    const label = status === 'failure' ? 'Failed' :
                  status === 'success' ? 'Success' :
                  status === 'running' ? 'Running' :
                  status;
    
    return `<span class="status-badge px-3 py-1 rounded-full ${badgeClass} text-sm">${label}</span>`;
}

function formatDateTime(isoString)
{
    const date = new Date(isoString);
    
    return {
        date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
        time: date.toLocaleTimeString('en-US', { hour12: false })
    };
}

function createDeploymentRow(deployment)
{
    const row = document.createElement('tr');
    row.className = 'hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors';
    row.dataset.deploymentId = deployment.id;
    row.dataset.startedAt = deployment.startedAtTimestamp;

    const datetime = formatDateTime(deployment.startedAt);
    const durationHtml = deployment.durationString
    ?
        `<span class="font-mono text-sm text-gray-600 dark:text-gray-300">${deployment.durationString}</span>`
    :
        `<div class="flex items-center text-gray-600 dark:text-gray-300">
            <svg class="animate-spin h-4 w-4 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span class="live-duration font-mono text-sm">0.0s</span>
        </div>`;

    row.innerHTML = `
        <td class="px-6 py-4 whitespace-nowrap">
            <span class="block text-sm text-gray-600 dark:text-gray-300">${deployment.message}</span>
        </td>
        
        <td class="px-6 py-4 whitespace-nowrap">
            <a href="/admin/deployments/${deployment.id}" class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-300 font-medium">${deployment.id}</a>
        </td>
        
        <td class="px-6 py-4 whitespace-nowrap">
            ${getStatusBadge(deployment.status)}
        </td>
        
        <td class="px-6 py-4 whitespace-nowrap">
            <span class="block text-sm text-gray-600 dark:text-gray-300">${datetime.date}</span>
            <span class="block text-gray-400 dark:text-gray-500 text-xs">${datetime.time}</span>
        </td>
        
        <td class="px-6 py-4 whitespace-nowrap">
            ${durationHtml}
        </td>
    `;

    return row;
}

function monitorDeployment(row)
{
    const durationElement = row.querySelector('.live-duration');
    const startTimestamp = parseFloat(row.dataset.startedAt);
    const statusCell = row.querySelector('td:nth-child(3)');
    
    // skip if already finished or missing required elements
    if (!durationElement || isNaN(startTimestamp)) return;
    
    // update duration every 100ms
    let lastDuration = 0;
    const updateDuration = () => {
        const now = Date.now() / 1000;
        lastDuration = (now - startTimestamp).toFixed(1);
        durationElement.textContent = `${lastDuration}s`;
    };
    const durationInterval = setInterval(updateDuration, 100);

    // update status every 5s
    const updateStatus = () => {
        fetch(`/admin/deployments/${row.dataset.deploymentId}`)
        .then(response => {
            if (!response.ok) throw new Error('Network error');
            return response.json();
        })
        .then(deployment => {
            if (deployment.finishedAt) {
                clearInterval(durationInterval);
                clearInterval(statusInterval);
                
                const durationCell = row.querySelector('td:nth-child(5)');
                if (durationCell) {
                    durationCell.innerHTML = `<span class="font-mono text-sm text-gray-600 dark:text-gray-300">${deployment.durationString}</span>`;
                }
                
                if (statusCell) {
                    statusCell.innerHTML = getStatusBadge(deployment.status);
                }
            }
        })
        .catch(error => console.error('Monitoring error:', error));
    }
    const statusInterval = setInterval(updateStatus, 5000);
    
    row.addEventListener('remove', () => {
        clearInterval(durationInterval);
        clearInterval(statusInterval);
    });
}

function monitorDeployments() {
    const tbody = document.querySelector('tbody');
    const existingIds = new Set();

    // Track existing deployments
    document.querySelectorAll('[data-deployment-id]').forEach(row => {
        existingIds.add(row.dataset.deploymentId);
    });

    // Check for new deployments
    setInterval(() => {
        fetch('/admin/deployments')
            .then(response => response.json())
            .then(deployments => {
                deployments.forEach(deployment => {
                    // new deployment found
                    if (!existingIds.has(deployment.id)) {
                        existingIds.add(deployment.id);
                        const newRow = createDeploymentRow(deployment);
                        tbody.insertBefore(newRow, tbody.firstChild);
                        
                        // start monitoring if it is currently running
                        if (!deployment.finishedAt) {
                            monitorDeployment(newRow);
                        }
                    }
                });
            })
            .catch(error => console.error('Error checking for new deployments:', error));
    }, 5000);

    // Initialize monitoring for existing deployments
    document.querySelectorAll('[data-deployment-id]').forEach(monitorDeployment);
}

document.addEventListener('DOMContentLoaded', () => 
{
    //monitorDeployments()
    connectWebSocket()
});
