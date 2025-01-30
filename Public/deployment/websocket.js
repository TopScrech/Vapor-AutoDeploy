// WebSocket connection
let socket = null;
let reconnectAttempts = 0;
const maxReconnectAttempts = 5;
let reconnectDelay = 1000;

function connect() 
{
    socket = new WebSocket('wss://mottzi.de/admin/ws/');
    
    socket.onopen = () => 
    {
        console.log('Connected to WebSocket');
        reconnectAttempts = 0;
        reconnectDelay = 1000;
    };
    
    socket.onmessage = (event) => 
    {
        console.log('Message from server:', event.data);
    };
    
    socket.onclose = () => 
    {
        console.log('Disconnected from WebSocket');
        handleReconnect();
    };
    
    socket.onerror = (error) => 
    {
        console.error('WebSocket error:', error);
    };
}

function handleReconnect() 
{
    if (reconnectAttempts < maxReconnectAttempts) 
    {
        reconnectAttempts++;
        console.log(`Attempting to reconnect (${reconnectAttempts}/${maxReconnectAttempts})...`);
        
        setTimeout(connect, reconnectDelay);
        reconnectDelay *= 2; // Exponential backoff
    } 
    else 
    {
        console.error('Max reconnection attempts reached');
    }
}

function sendMessage(message) 
{
    if (socket && socket.readyState === WebSocket.OPEN) 
    {
        socket.send(message);
    } 
    else 
    {
        console.error('WebSocket is not connected');
    }
}

// Start the connection
connect();
