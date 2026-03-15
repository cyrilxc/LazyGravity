const fs = require('fs');
let code = fs.readFileSync('src/services/userMessageDetector.ts', 'utf8');

// Change import to include EventEmitter
code = "import { EventEmitter } from 'events';\n" + code.replace(/import \{ createHash \} from 'node:crypto';/, "import { createHash } from 'node:crypto';");

// Make UserMessageDetector extend EventEmitter
code = code.replace(/export class UserMessageDetector \{/, "export class UserMessageDetector extends EventEmitter {");

// Change constructor to call super()
code = code.replace(/constructor\(options: UserMessageDetectorOptions\) \{/, "constructor(options: UserMessageDetectorOptions) {\n        super();");

// Replace onUserMessage options
code = code.replace(/    private readonly onUserMessage: \(info: UserMessageInfo\) => void;\n/, "");
code = code.replace(/    \/\*\* Callback when a new user message is detected \*\/\n    onUserMessage: \(info: UserMessageInfo\) => void;\n/, "");
code = code.replace(/        this.onUserMessage = options.onUserMessage;\n/, "");

// Replace this.onUserMessage(info) with this.emit('message', info)
code = code.replace(/this\.onUserMessage\(info\);/g, "this.emit('message', info);");

fs.writeFileSync('src/services/userMessageDetector.ts', code);
