class MistSocket
{
    constructor()
    {
        // websocket
        this.socket = null;
        
        // reconnect
        this.timer = null;
        this.initialDelay = 1000;
        this.interval = 5000;
        
        document.addEventListener('visibilitychange', () => this.visibilityChange());
        window.addEventListener('online', () => this.connect());
        
        // subscribe to all components on page load
        this.subscribeToPageComponents();
    }
    
    subscribeToPageComponents()
    {
        // find all elements with mist-component attribute
        document.querySelectorAll('[mist-component]').forEach(element =>
        {
            const component = element.getAttribute('mist-component');
            
            if (component)
            {
                this.subscribe(component);
            }
        });
    }
    
    subscribe(component)
    {
        if (this.isConnected())
        {
            const message =
            {
                type: 'subscribe',
                component: component
            };
            
            this.socket.send(JSON.stringify(message));
        }
    }
    
    unsubscribe(component)
    {
        if (this.isConnected())
        {
            const message =
            {
                type: 'unsubscribe',
                component: component
            };
            
            this.socket.send(JSON.stringify(message));
        }
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
        this.socket = new WebSocket('wss://mottzi.de/mist/ws/');
        
        // connected: stop existing reconnect timer
        this.socket.onopen = () =>
        {
            if (this.timer) { clearInterval(this.timer); this.timer = null; }
            
            // Resubscribe to components after reconnection ???
            this.subscribeToPageComponents();
        };
        
        // parse incoming messages
        this.socket.onmessage = (event) =>
        {
            try
            {
                console.log(`RAW: ${event.data}`);
                const data = JSON.parse(event.data);
                
                if (data.type === 'componentUpdate')
                {
                    const elements = document.querySelectorAll(`[mist-component="${data.component}"][mist-id="${data.id}"]`);
                    
                    elements.forEach(element =>
                    {
                        element.outerHTML = data.html;
                    });
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
                
                console.log("WS: ... closed -> Connect in 1s ...");
            
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
        if (document.visibilityState === "visible")
        {
            console.log('visibilityState === "visible" -> calling connect()')
            this.connect();
        }
    }
}

// Wait for the DOM to be fully loaded before executing the code
document.addEventListener('DOMContentLoaded', function ()
{
    window.ws = new MistSocket();
    window.ws.connect()
});
