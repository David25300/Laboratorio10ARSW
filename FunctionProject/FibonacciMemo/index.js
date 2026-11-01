var bigInt = require("big-integer");

// La memoria vive fuera del handler: solo dura mientras la instancia siga viva
var memo = new Map();

function fibonacci(n) {
    if (n <= 1)
        return bigInt(n);
    if (memo.has(n))
        return memo.get(n);

    let value = fibonacci(n - 1).add(fibonacci(n - 2));
    memo.set(n, value);
    return value;
}

module.exports = async function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');

    let nth = req.body.nth
    if (nth < 0)
        throw 'must be greater than 0'

    let memoBefore = memo.size;
    let start = Date.now();
    let info = {
        nth: nth,
        instance: (process.env.WEBSITE_INSTANCE_ID || 'local').substring(0, 8),
        uptimeSeconds: Math.round(process.uptime()),
        memoBefore: memoBefore
    };

    try {
        let answer = fibonacci(nth);
        info.memoAfter = memo.size;
        info.timeMs = Date.now() - start;
        info.answer = answer.toString();
        context.res = { body: info };
    } catch (e) {
        info.memoAfter = memo.size;
        info.timeMs = Date.now() - start;
        info.error = e.toString();
        context.res = { status: 500, body: info };
    }
}
