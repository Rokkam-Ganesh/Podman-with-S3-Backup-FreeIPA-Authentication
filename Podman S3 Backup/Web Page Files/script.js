document.addEventListener('DOMContentLoaded', function() {
    updateTimestamp();
    loadBackupInfo();
});

function updateTimestamp() {
    const now = new Date();
    document.getElementById('current-time').textContent = now.toLocaleString();
}

function loadData() {
    const dataDisplay = document.getElementById('data-display');
    const sampleData = [
        { id: 1, name: 'Server Log Entry', timestamp: new Date().toISOString() },
        { id: 2, name: 'User Session Data', value: 'Active Sessions: 5' },
        { id: 3, name: 'System Metrics', value: 'CPU: 15%, Memory: 45%' },
        { id: 4, name: 'Container Status', value: 'Running: Healthy' }
    ];
    
    let html = '<h3>Sample Application Data:</h3><ul>';
    sampleData.forEach(item => {
        html += `<li><strong>${item.name}:</strong> ${item.value || item.timestamp}</li>`;
    });
    html += '</ul>';
    
    dataDisplay.innerHTML = html;
    
    saveDataToFile(sampleData);
}

function saveDataToFile(data) {
    console.log('Data would be saved to server:', data);
}

function loadBackupInfo() {
    setTimeout(() => {
        document.getElementById('last-backup').textContent = 'Simulated: ' + new Date().toLocaleString();
    }, 1000);
}
