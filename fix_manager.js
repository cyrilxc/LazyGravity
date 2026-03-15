const fs = require('fs');
let code = fs.readFileSync('src/services/cdpBridgeManager.ts', 'utf8');

const oldFunc = /export function ensureUserMessageDetector\([\s\S]*?logger\.debug\(\`\[UserMessageDetector:\$\{projectName\}\] Started user message detection\`\);\n\}/m;

const newFunc = `export function ensureUserMessageDetector(
    bridge: CdpBridge,
    cdp: CdpService,
    projectName: string,
    onUserMessage: (info: UserMessageInfo) => void,
): void {
    const existing = bridge.pool.getUserMessageDetector(projectName);
    if (existing && existing.isActive()) {
        existing.on('message', onUserMessage);
        return;
    }

    const detector = new UserMessageDetector({
        cdpService: cdp,
        pollIntervalMs: 2000,
    });
    
    detector.on('message', onUserMessage);
    detector.start();
    bridge.pool.registerUserMessageDetector(projectName, detector);
    logger.debug(\`[UserMessageDetector:\${projectName}] Started user message detection\`);
}`;

code = code.replace(oldFunc, newFunc);
fs.writeFileSync('src/services/cdpBridgeManager.ts', code);
