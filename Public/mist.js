class Mist
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
        };
        
        // parse incoming messages
        this.socket.onmessage = (event) =>
        {
            try
            {
                console.log(event.data)

                const data = JSON.parse(event.data);
                
                // respond to server message here
                // ...
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

document.addEventListener('DOMContentLoaded', () => ws = new Mist().connect());
