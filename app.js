// Application State
let rules = [];
let ruleIdCounter = 0;

// Preset configurations
const presets = {
    corporate: [
        { original: 'MiscellaneousCorp', replacement: 'AnonymousCorp', caseSensitive: false, wholeWord: true },
        { original: 'Project Phoenix', replacement: 'Project Parakeet', caseSensitive: false, wholeWord: true },
        { original: 'CEO', replacement: 'CFO', caseSensitive: false, wholeWord: true },
        { original: 'Q4', replacement: 'Period Four', caseSensitive: false, wholeWord: true }
    ],
    personal: [
        { original: 'john.doe@', replacement: 'user123@', caseSensitive: false, wholeWord: false },
        { original: 'John Doe', replacement: 'Jane Smith', caseSensitive: false, wholeWord: true },
        { original: '+44', replacement: '+00', caseSensitive: false, wholeWord: false },
        { original: '555-', replacement: '000-', caseSensitive: false, wholeWord: false }
    ],
    financial: [
        { original: '$', replacement: '£', caseSensitive: false, wholeWord: false },
        { original: 'USD', replacement: 'CURRENCY', caseSensitive: false, wholeWord: true },
        { original: 'Account #', replacement: 'Acct #', caseSensitive: false, wholeWord: false },
        { original: 'Budget:', replacement: 'Amount:', caseSensitive: false, wholeWord: false }
    ]
};

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    initializeEventListeners();
    loadRulesFromStorage();
    
    // Add initial rule if none exist
    if (rules.length === 0) {
        addRule('BlahBlahCorp', 'PotatoesIncorporated', false, true);
    }
});

// Event Listeners
function initializeEventListeners() {
    document.getElementById('add-rule-btn').addEventListener('click', () => addRule());
    document.getElementById('obfuscate-btn').addEventListener('click', obfuscateText);
    document.getElementById('copy-btn').addEventListener('click', copyToClipboard);
    document.getElementById('clear-text-btn').addEventListener('click', clearText);
    document.getElementById('save-rules-btn').addEventListener('click', saveRulesToFile);
    document.getElementById('load-rules-btn').addEventListener('click', loadRulesFromFile);
    document.getElementById('clear-rules-btn').addEventListener('click', clearAllRules);
    
    // Input text listeners
    document.getElementById('input-text').addEventListener('input', updateCharCount);
    document.getElementById('input-text').addEventListener('input', () => {
        document.getElementById('output-text').value = '';
        document.getElementById('copy-btn').disabled = true;
        document.getElementById('mapping-display').style.display = 'none';
        updateOutputCharCount();
    });
}

// Rule Management
function addRule(original = '', replacement = '', caseSensitive = false, wholeWord = true) {
    const rule = {
        id: ruleIdCounter++,
        original,
        replacement,
        caseSensitive,
        wholeWord
    };
    
    rules.push(rule);
    renderRule(rule);
    saveRulesToStorage();
}

function removeRule(id) {
    rules = rules.filter(rule => rule.id !== id);
    document.getElementById(`rule-${id}`).remove();
    saveRulesToStorage();
}

function renderRule(rule) {
    const container = document.getElementById('rules-container');
    const ruleDiv = document.createElement('div');
    ruleDiv.className = 'rule-item';
    ruleDiv.id = `rule-${rule.id}`;
    
    ruleDiv.innerHTML = `
        <button class="remove-rule" onclick="removeRule(${rule.id})">×</button>
        <label>Find:</label>
        <input type="text" 
               class="rule-original" 
               value="${escapeHtml(rule.original)}" 
               placeholder="e.g., BlahBlahCorp"
               data-rule-id="${rule.id}">
        <label>Replace with:</label>
        <input type="text" 
               class="rule-replacement" 
               value="${escapeHtml(rule.replacement)}" 
               placeholder="e.g., PotatoesIncorporated"
               data-rule-id="${rule.id}">
        <div class="rule-options">
            <label>
                <input type="checkbox" 
                       class="rule-case-sensitive" 
                       ${rule.caseSensitive ? 'checked' : ''}
                       data-rule-id="${rule.id}">
                Case sensitive
            </label>
            <label>
                <input type="checkbox" 
                       class="rule-whole-word" 
                       ${rule.wholeWord ? 'checked' : ''}
                       data-rule-id="${rule.id}">
                Whole word
            </label>
        </div>
    `;
    
    container.appendChild(ruleDiv);
    
    // Add event listeners for rule inputs
    ruleDiv.querySelectorAll('input').forEach(input => {
        input.addEventListener('input', updateRuleFromInput);
        input.addEventListener('change', updateRuleFromInput);
    });
}

function updateRuleFromInput(event) {
    const ruleId = parseInt(event.target.dataset.ruleId);
    const rule = rules.find(r => r.id === ruleId);
    
    if (!rule) return;
    
    const ruleElement = document.getElementById(`rule-${ruleId}`);
    rule.original = ruleElement.querySelector('.rule-original').value;
    rule.replacement = ruleElement.querySelector('.rule-replacement').value;
    rule.caseSensitive = ruleElement.querySelector('.rule-case-sensitive').checked;
    rule.wholeWord = ruleElement.querySelector('.rule-whole-word').checked;
    
    saveRulesToStorage();
}

function renderAllRules() {
    const container = document.getElementById('rules-container');
    container.innerHTML = '';
    rules.forEach(rule => renderRule(rule));
}

// Obfuscation Logic
function obfuscateText() {
    const inputText = document.getElementById('input-text').value;
    const outputTextarea = document.getElementById('output-text');
    const mappingDisplay = document.getElementById('mapping-display');
    const mappingList = document.getElementById('mapping-list');
    
    if (!inputText.trim()) {
        alert('Please enter some text to obfuscate.');
        return;
    }
    
    if (rules.length === 0 || rules.every(r => !r.original)) {
        alert('Please add at least one obfuscation rule.');
        return;
    }
    
    let outputText = inputText;
    const appliedMappings = [];
    
    // Apply each rule
    rules.forEach(rule => {
        if (!rule.original) return;
        
        const searchTerm = rule.original;
        const replaceTerm = rule.replacement || '[REDACTED]';
        
        let flags = 'g'; // global
        if (!rule.caseSensitive) flags += 'i'; // case insensitive
        
        let pattern;
        if (rule.wholeWord) {
            // Escape special regex characters and add word boundaries
            const escaped = searchTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            pattern = new RegExp(`\\b${escaped}\\b`, flags);
        } else {
            const escaped = searchTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            pattern = new RegExp(escaped, flags);
        }
        
        // Check if the pattern matches anything
        const matches = outputText.match(pattern);
        if (matches && matches.length > 0) {
            outputText = outputText.replace(pattern, replaceTerm);
            appliedMappings.push({
                original: searchTerm,
                replacement: replaceTerm,
                count: matches.length
            });
        }
    });
    
    outputTextarea.value = outputText;
    document.getElementById('copy-btn').disabled = false;
    updateOutputCharCount();
    
    // Show mappings
    if (appliedMappings.length > 0) {
        mappingList.innerHTML = appliedMappings.map(mapping => `
            <div class="mapping-item">
                <span class="original">${escapeHtml(mapping.original)}</span>
                <span class="arrow">→</span>
                <span class="replacement">${escapeHtml(mapping.replacement)}</span>
                <span style="color: #666; margin-left: 8px;">(${mapping.count} ${mapping.count === 1 ? 'match' : 'matches'})</span>
            </div>
        `).join('');
        mappingDisplay.style.display = 'block';
    } else {
        mappingDisplay.style.display = 'none';
        alert('No matches found. Check your obfuscation rules.');
    }
}

// Copy to Clipboard
function copyToClipboard() {
    const outputText = document.getElementById('output-text');
    const feedback = document.getElementById('copy-feedback');
    
    outputText.select();
    outputText.setSelectionRange(0, 99999); // For mobile devices
    
    navigator.clipboard.writeText(outputText.value).then(() => {
        feedback.textContent = '✓ Copied!';
        feedback.classList.add('show');
        
        setTimeout(() => {
            feedback.classList.remove('show');
        }, 2000);
    }).catch(err => {
        alert('Failed to copy text. Please try manually selecting and copying.');
        console.error('Copy failed:', err);
    });
}

// Clear Text
function clearText() {
    document.getElementById('input-text').value = '';
    document.getElementById('output-text').value = '';
    document.getElementById('copy-btn').disabled = true;
    document.getElementById('mapping-display').style.display = 'none';
    updateCharCount();
    updateOutputCharCount();
}

// Character Count
function updateCharCount() {
    const inputText = document.getElementById('input-text').value;
    document.getElementById('input-count').textContent = `${inputText.length} characters`;
}

function updateOutputCharCount() {
    const outputText = document.getElementById('output-text').value;
    document.getElementById('output-count').textContent = `${outputText.length} characters`;
}

// Preset Loading
function loadPreset(presetName) {
    if (!presets[presetName]) return;
    
    const confirmLoad = rules.length > 0 
        ? confirm('This will replace your current rules. Continue?')
        : true;
    
    if (!confirmLoad) return;
    
    rules = [];
    ruleIdCounter = 0;
    
    presets[presetName].forEach(preset => {
        addRule(preset.original, preset.replacement, preset.caseSensitive, preset.wholeWord);
    });
}

// Storage Management
function saveRulesToStorage() {
    try {
        localStorage.setItem('obfuscatorRules', JSON.stringify(rules));
    } catch (e) {
        console.error('Failed to save rules to storage:', e);
    }
}

function loadRulesFromStorage() {
    try {
        const stored = localStorage.getItem('obfuscatorRules');
        if (stored) {
            const loadedRules = JSON.parse(stored);
            rules = loadedRules;
            ruleIdCounter = Math.max(...rules.map(r => r.id), 0) + 1;
            renderAllRules();
        }
    } catch (e) {
        console.error('Failed to load rules from storage:', e);
    }
}

// File Export/Import
function saveRulesToFile() {
    if (rules.length === 0) {
        alert('No rules to save.');
        return;
    }
    
    const dataStr = JSON.stringify(rules, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `obfuscation-rules-${Date.now()}.json`;
    link.click();
    URL.revokeObjectURL(url);
}

function loadRulesFromFile() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    
    input.onchange = e => {
        const file = e.target.files[0];
        if (!file) return;
        
        const reader = new FileReader();
        reader.onload = event => {
            try {
                const loadedRules = JSON.parse(event.target.result);
                
                if (!Array.isArray(loadedRules)) {
                    throw new Error('Invalid file format');
                }
                
                const confirmLoad = rules.length > 0 
                    ? confirm('This will replace your current rules. Continue?')
                    : true;
                
                if (!confirmLoad) return;
                
                rules = loadedRules;
                ruleIdCounter = Math.max(...rules.map(r => r.id), 0) + 1;
                renderAllRules();
                saveRulesToStorage();
                alert('Rules loaded successfully!');
            } catch (err) {
                alert('Failed to load rules file. Please check the file format.');
                console.error('Load error:', err);
            }
        };
        reader.readAsText(file);
    };
    
    input.click();
}

function clearAllRules() {
    if (rules.length === 0) return;
    
    const confirm = window.confirm('Are you sure you want to clear all rules?');
    if (!confirm) return;
    
    rules = [];
    ruleIdCounter = 0;
    document.getElementById('rules-container').innerHTML = '';
    saveRulesToStorage();
}

// Utility Functions
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
