// Only cache path which is not in officail cache
const http = require('http');
const server = http.createServer((req, res) => {

    if (/.*narinfo$/.test(req.url)) {
        // *.narinfo   
        let narinfoPath = req.url.substring(7)  // remove bucket /kexec/ prefix in req.url
        http.get(`http://cache.nixos.org/${narinfoPath}`, officialCacheResponse => {
            if (officialCacheResponse.statusCode == 200) { // path exists in cache.nixos.org, do not need to cache it
                res.writeHead(officialCacheResponse.statusCode, officialCacheResponse.headers);
                officialCacheResponse.pipe(res);
            } else { // path does not exist in cache.nixos.org, cache it
                res.statusCode = 302;
                res.setHeader('Location', `http://minio.mlyxshi.com${req.url}`);
                res.end();
            }
        });
    } else {
        // nix-cache-info
        // *.nar.zst
        res.statusCode = 302;
        res.setHeader('Location', `http://minio.mlyxshi.com${req.url}`);
        res.end();
    }


});

server.listen(process.env.CACHE_PROXY_PORT || 5555, '127.0.0.1');