// RetailMart Dashboard JavaScript

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

// Format numbers Indian style (Lakhs, Crores)
function formatCurrency(num) {
    if (num >= 10000000) return '₹' + (num / 10000000).toFixed(2) + ' Cr';
    if (num >= 100000) return '₹' + (num / 100000).toFixed(2) + ' L';
    return '₹' + num.toLocaleString('en-IN');
}

function formatNumber(num) {
    return num.toLocaleString('en-IN');
}

// Chart.js color palette
const colors = {
    primary: '#1E3A5F',
    secondary: '#2E7D32',
    accent: '#E65100',
    palette: ['#1E3A5F', '#2E7D32', '#E65100', '#7B1FA2', '#00838F', '#C62828', '#F57C00', '#1565C0']
};

// ============================================================
// LOAD AND DISPLAY DATA
// ============================================================

// Load Sales Overview
async function loadSalesOverview() {
    try {
        const response = await fetch('data/sales_overview.json');
        const json = await response.json();
        const data = json.data;

        document.getElementById('total-revenue').textContent = formatCurrency(data.total_revenue);
        document.getElementById('total-orders').textContent = formatNumber(data.total_orders);
        document.getElementById('total-customers').textContent = formatNumber(data.total_customers);
        document.getElementById('avg-order-value').textContent = formatCurrency(data.avg_order_value);
        document.getElementById('last-updated').textContent = new Date(json.generated_at).toLocaleString();
    } catch (error) {
        console.error('Error loading sales overview:', error);
    }
}

// Load and render Monthly Trend Chart
async function loadMonthlyTrend() {
    try {
        const response = await fetch('data/monthly_trends.json');
        const json = await response.json();

        new Chart(document.getElementById('revenueChart'), {
            type: 'line',
            data: {
                labels: json.data.map(d => d.month),
                datasets: [{
                    label: 'Revenue',
                    data: json.data.map(d => d.revenue),
                    borderColor: colors.primary,
                    backgroundColor: 'rgba(30, 58, 95, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                plugins: { legend: { display: false } },
                scales: {
                    y: { beginAtZero: true, ticks: { callback: v => formatCurrency(v) } }
                }
            }
        });
    } catch (error) {
        console.error('Error loading monthly trends:', error);
    }
}

// Load and render Category Chart
async function loadCategorySales() {
    try {
        const response = await fetch('data/category_sales.json');
        const json = await response.json();

        new Chart(document.getElementById('categoryChart'), {
            type: 'doughnut',
            data: {
                labels: json.data.map(d => d.category),
                datasets: [{
                    data: json.data.map(d => d.revenue),
                    backgroundColor: colors.palette
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: { position: 'right' }
                }
            }
        });
    } catch (error) {
        console.error('Error loading category sales:', error);
    }
}

// Load and render Customer Segments Chart
async function loadCustomerSegments() {
    try {
        const response = await fetch('data/customer_segments.json');
        const json = await response.json();

        new Chart(document.getElementById('segmentChart'), {
            type: 'bar',
            data: {
                labels: json.data.map(d => d.segment),
                datasets: [{
                    label: 'Customers',
                    data: json.data.map(d => d.customer_count),
                    backgroundColor: colors.palette
                }]
            },
            options: {
                responsive: true,
                plugins: { legend: { display: false } },
                scales: { y: { beginAtZero: true } }
            }
        });
    } catch (error) {
        console.error('Error loading customer segments:', error);
    }
}

// Load and render Top Products Chart
async function loadTopProducts() {
    try {
        const response = await fetch('data/top_products.json');
        const json = await response.json();

        new Chart(document.getElementById('productsChart'), {
            type: 'bar',
            data: {
                labels: json.data.map(d => d.product_name.substring(0, 20) + '...'),
                datasets: [{
                    label: 'Revenue',
                    data: json.data.map(d => d.revenue),
                    backgroundColor: colors.secondary
                }]
            },
            options: {
                indexAxis: 'y',
                responsive: true,
                plugins: { legend: { display: false } },
                scales: {
                    x: { ticks: { callback: v => formatCurrency(v) } }
                }
            }
        });
    } catch (error) {
        console.error('Error loading top products:', error);
    }
}

// Load Store Performance Table
async function loadStorePerformance() {
    try {
        const response = await fetch('data/store_performance.json');
        const json = await response.json();
        const tbody = document.querySelector('#store-table tbody');

        tbody.innerHTML = json.data.map(store => `
            <tr>
                <td>${store.store_name}</td>
                <td>${store.city}</td>
                <td>${store.region}</td>
                <td>${formatCurrency(store.revenue)}</td>
                <td>${formatNumber(store.orders)}</td>
                <td class="status-${store.performance_tier.toLowerCase().replace(' ', '-')}">
                    ${store.performance_tier === 'Star' ? '⭐ ' : ''}${store.performance_tier}
                </td>
            </tr>
        `).join('');
    } catch (error) {
        console.error('Error loading store performance:', error);
    }
}

// ============================================================
// INITIALIZE DASHBOARD
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
    loadSalesOverview();
    loadMonthlyTrend();
    loadCategorySales();
    loadCustomerSegments();
    loadTopProducts();
    loadStorePerformance();
});
