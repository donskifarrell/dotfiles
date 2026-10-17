"""HTTP contract for the packaged server; no LAN listener or live systemd changes."""

import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


with tempfile.TemporaryDirectory(prefix=".quest-video-test-", dir=".") as directory:
    root = Path(directory).resolve()
    media = root / "media"
    media.mkdir()
    content = b"0123456789abcdef"
    (media / "test video.mp4").write_bytes(content)
    (media / ".hidden.mp4").write_bytes(b"hidden")
    (root / "private.txt").write_bytes(b"private")
    (media / "escape.txt").symlink_to(root / "private.txt")
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    url = f"http://127.0.0.1:{port}"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with tempfile.TemporaryFile(dir=root) as log:
        server = subprocess.Popen(
            [sys.argv[1], "--interfaces", "127.0.0.1", "--port", str(port),
             "--no-symlinks", str(media)],
            stdout=log, stderr=log,
        )
        try:
            for _ in range(100):
                assert server.poll() is None, "miniserve exited before readiness"
                try:
                    with opener.open(url, timeout=1) as response:
                        listing = response.read()
                    break
                except urllib.error.URLError:
                    time.sleep(0.05)
            else:
                raise AssertionError("miniserve did not become ready")
            assert b"test video.mp4" in listing
            assert b"escape.txt" not in listing and b".hidden.mp4" not in listing
            request = urllib.request.Request(
                url + "/test%20video.mp4", headers={"Range": "bytes=4-9"}
            )
            with opener.open(request, timeout=2) as response:
                assert response.status == 206
                assert response.headers["Content-Range"] == "bytes 4-9/16"
                assert response.headers.get_content_type() == "video/mp4"
                assert "attachment" not in response.headers.get("Content-Disposition", "")
                assert response.read() == content[4:10]
            for path, method in [
                ("/escape.txt", "GET"), ("/.hidden.mp4", "GET"),
                ("/%2e%2e/private.txt", "GET"), ("/upload", "POST"),
                ("/test%20video.mp4", "DELETE"),
            ]:
                try:
                    opener.open(urllib.request.Request(url + path, method=method), timeout=2)
                except urllib.error.HTTPError as error:
                    assert error.code in (400, 403, 404, 405), (path, error.code)
                else:
                    raise AssertionError(f"Unexpected access: {method} {path}")
            assert (media / "test video.mp4").read_bytes() == content
            print("PASS: listing, inline MP4/range seeking, hidden/symlink/traversal denial, no writes")
        finally:
            server.terminate()
            server.wait(timeout=5)
