// this js script makes the table auto-update 2
class DeploymentSocket
{
    constructor() 
    {
        // websocket
        this.socket = null;
        this.deploymentManager = new DeploymentManager();

        // reconnect
        this.timer = null;
        this.initialDelay = 1000;    
        this.interval = 5000;
        
        document.addEventListener('visibilitychange', () => this.visibilityChange());
        window.addEventListener('online', () => this.connect());
    }

    isConnected() { return this.socket?.readyState === WebSocket.OPEN; }
    isConnecting() { return this.socket?.readyState === WebSocket.CONNECTING; }

    connect()
    {
        // abort if already connected or currently connecting
        if (this.isConnected() || this.isConnecting()) return;
        
        // close existing socket
        if (this.socket) { this.socket.close(); this.socket = null; }

        // create new socket and try to connect
        //console.log('WS: Connecting ...');
        this.socket = new WebSocket('wss://mottzi.de/admin/ws');
        
         // connected: stop existing reconnect timer
        this.socket.onopen = () =>
        {
            console.log('WS: ... connected!');
            if (this.timer) { clearInterval(this.timer); this.timer = null; }
        };

        // parse incoming messages
        this.socket.onmessage = (event) => 
        {
            try 
            {
                const data = JSON.parse(event.data);
                
                switch (data.type)
                {
                    case 'state':
                        console.log(`STATE: ${data.deployments.length} Deployments`);
                        this.deploymentManager.handleState(data.deployments);
                        break;

                    case 'creation':
                        console.log(`CREATION: ${data.deployment.message}`);
                        this.deploymentManager.handleCreation(data.deployment);
                        break;
                        
                    case 'update':
                        console.log(`UPDATE: ${data.deployment.message}`);
                        this.deploymentManager.handleUpdate(data.deployment);
                        break;

                    case 'message':
                        console.log(`MESSAGE: ${data.message}`);
                        break;
                        
                    default:
                        console.log(`Unknown message type: ${data.type}`);
                        break;
                }
            }
            catch (error) 
            {
                console.error(`WS: Failed to parse message: ${error}`);
            }
        };

        // disconnected: start reconnect timer
        this.socket.onclose = () => 
        {
            // abort if a reconnect timer is already running
            if (this.timer) return
                
            console.log('WS: ... closed -> Connect in 1s ...');
            
            // start trying every 5s
            setTimeout(() => 
            {
                this.connect();

                this.timer = setInterval(() => 
                {
                    this.connect();
                }, 
                this.interval);
            }, 
            this.initialDelay);
        };
    }

    visibilityChange()
    {
        if (document.visibilityState === 'visible') this.connect();
    }
}

class DeploymentManager 
{
    constructor() 
    {
        this.activeTimers = new Map();
        this.startExistingTimers();
    }

    // handle incoming messages

    handleState(deployments)
    {
        // remove all existing rows
        document.querySelector('tbody').innerHTML = '';

        // clear all existing timers
        this.activeTimers.forEach((_, deploymentId) => this.clearTimer(deploymentId));

        // create new rows for each deployment
        deployments.reverse();
        deployments.forEach(deployment => this.handleCreation(deployment));
    }

    handleCreation(deployment) 
    {
        // abort if row already exists
        let row = document.querySelector(`tr[data-deployment-id="${deployment.id}"]`);
        if (row) return;
        
        // create new row
        row = document.createElement('tr');
        row.innerHTML = this.rowHTML(deployment);
        row.dataset.deploymentId = deployment.id;
        row.dataset.startedAt = deployment.startedAtTimestamp;
        row.className = 'hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors';
        
        // add row to table
        const tbody = document.querySelector('tbody');
        tbody.prepend(row);
        
        // start new timer
        this.setupTimer(row);
    }

//    handleUpdate(deployment) 
//    {
//        // abort if deployment is still running
//        if (deployment.status == 'running') return;
//
//        // abort if row does not exist
//        const row = document.querySelector(`tr[data-deployment-id="${deployment.id}"]`);
//        if (!row) return;
//
//        // clear duartion timer
//        this.clearTimer(deployment.id);
//
//        // update duration cell
//        const durationCell = row.querySelector('td:nth-child(5)');
//        if (durationCell) { durationCell.innerHTML = `<span class="font-mono text-sm text-gray-600 dark:text-gray-300">${deployment.durationString}</span>`; }
//
//        // update status cell
//        const statusCell = row.querySelector('td:nth-child(3)');
//        if (statusCell) { statusCell.innerHTML = this.statusHTML(deployment.status); }
//    }
    
    handleUpdate(deployment)
    {
        // abort if row does not exist
        const row = document.querySelector(`tr[data-deployment-id="${deployment.id}"]`);
        if (!row) return;
        
        // update status cell
        const statusCell = row.querySelector('td:nth-child(3)');
        if (statusCell) { statusCell.innerHTML = this.statusHTML(deployment.status); }
        
        // if status is 'running', setup the timer
        if (deployment.status === 'running')
        {
            this.setupTimer(row);
        }
        // if status is final (not running), update duration and clear timer
        else
        {
            this.clearTimer(deployment.id);
            
            const durationCell = row.querySelector('td:nth-child(5)');
            if (durationCell) { durationCell.innerHTML = `<span class="font-mono text-sm text-gray-600 dark:text-gray-300">${deployment.durationString}</span>`; }
        }
    }

    // timer management

    startExistingTimers()
    {
        // create duration timer for each deployment row that is currently running
        document.querySelectorAll('tr[data-deployment-id]').forEach(row => 
        {            
            if (row.querySelector('.status-badge')?.textContent.includes('Running'))
            {
                this.setupTimer(row);
            }
        });
    }

    setupTimer(row) 
    {
        // clear existing deployment duration timer
        this.clearTimer(row.dataset.deploymentId);

        const durationElement = row.querySelector('.live-duration');
        const startTimestamp = parseFloat(row.dataset.startedAt);
        
        // abort if duration element or start timestamp is missing
        if (!durationElement || isNaN(startTimestamp)) return;

        const update = () => 
        {
            const now = Date.now() / 1000;
            durationElement.textContent = `${(now - startTimestamp).toFixed(1)}s`;
        };

        // create new duration timer for deployment
        const intervalId = setInterval(update, 100);
        this.activeTimers.set(row.dataset.deploymentId, intervalId);
    }

    clearTimer(deploymentId) 
    {
        // if deployment duration timer exists
        if (this.activeTimers.has(deploymentId)) 
        {
            // clean timer
            clearInterval(this.activeTimers.get(deploymentId));
            this.activeTimers.delete(deploymentId);
        }
    }

    // DOM manipulation

    rowHTML(deployment) 
    {
        return `
            <tr class="hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors" 
                data-deployment-id="${deployment.id}" 
                data-started-at="${deployment.startedAtTimestamp}"
            >
                <td class="px-6 py-4 max-w-[160px]">
                    <span class="block text-sm text-gray-600 dark:text-gray-300 truncate">${deployment.message}</span>
                </td>
                
                <td class="hidden sm:table-cell px-6 py-4">
                    <a href="/admin/deployments/${deployment.id}" class="font-mono text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-300 font-medium text-sm">${deployment.id}</a>
                </td>
                
                <td class="px-6 py-4">
                    ${this.statusHTML(deployment.status)}
                </td>
                
                <td class="hidden sm:table-cell px-6 py-4">
                    <span class="block text-sm text-gray-600 dark:text-gray-300">${this.formatDate(deployment.startedAtTimestamp * 1000)}</span>
                    <span class="block text-gray-400 dark:text-gray-500 text-xs">${this.formatTime(deployment.startedAtTimestamp * 1000)}</span>
                </td>
                
                <td class="px-6 py-4">
                    ${deployment.durationString ? this.durationHTML(deployment.durationString) : deployment.status == "stale" || deployment.status == "canceled" ? this.durationHTML("NaN") : this.spinnerHTML()}
                </td>
            </tr>`;
    }

    statusHTML(status) 
    {
        let className, label;
        
        switch(status) 
        {
            case 'success':
                className = 'bg-green-100 text-green-800 dark:bg-green-800/30 dark:text-green-200';
                label = 'Success';
                break;

            case 'failed':
                className = 'bg-red-100 text-red-800 dark:bg-red-800/30 dark:text-red-200';
                label = 'Failed';
                break;

            case 'running':
                className = 'bg-blue-100 text-blue-800 dark:bg-blue-800/30 dark:text-blue-200';
                label = 'Running';
                break;

            case 'stale':
                className = 'bg-orange-100 text-orange-800 dark:bg-orange-800/30 dark:text-orange-200';
                label = 'Stale';
                break;
                
            case 'canceled':
                className = 'bg-orange-100 text-orange-800 dark:bg-orange-800/30 dark:text-orange-200';
                label = 'Canceled';
                break;

            default:
                className = 'bg-blue-100 text-blue-800 dark:bg-blue-800/30 dark:text-blue-200';
                label = status;
        }
        
        return `<span class="status-badge px-2 py-1 sm:px-3 rounded-full ${className} text-sm">${label}</span>`;
    }

    durationHTML(durationString) 
    {
        return `<span class="font-mono text-sm text-gray-600 dark:text-gray-300">${durationString}</span>`;
    }

    spinnerHTML() 
    {
        return `
            <div class="flex items-center text-gray-600 dark:text-gray-300">
                <svg class="animate-spin h-4 w-4 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <span class="live-duration font-mono text-sm">0.0s</span>
            </div>`;
    }

    formatDate(timestamp) 
    {
        return new Date(timestamp).toLocaleDateString('en-US', 
        { 
            month: 'short',
            day: 'numeric', 
            year: 'numeric'
        });
    }

    formatTime(timestamp) 
    {
        return new Date(timestamp).toLocaleTimeString('en-US', 
        { 
            hour12: false,
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
    }
}

document.addEventListener('DOMContentLoaded', () => new DeploymentSocket().connect());
