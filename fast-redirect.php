<?php
/*
Plugin Name: Fast Redirect (PageSpeed Friendly)
Description: ระบบ Redirect ความเร็วสูง + ดึง Config จาก GitHub
Version: 11.0
*/
add_action('muplugins_loaded', function() {

    $path = rtrim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/');

    // ===== ดึง url-link.json จาก GitHub (Cache 5 นาที) =====
    $cache_file = sys_get_temp_dir() . '/fast-redirect-url-link.json';
    $cache_time = 300; // 5 นาที

    if (!file_exists($cache_file) || (time() - filemtime($cache_file)) > $cache_time) {
        $json = @file_get_contents(
            'https://raw.githubusercontent.com/ufavision/remove3page-add-fast-redirect-muplugin/main/url-link.json'
        );
        if ($json) {
            file_put_contents($cache_file, $json);
        }
    }

    $url_link = [];
    if (file_exists($cache_file)) {
        $url_link = json_decode(file_get_contents($cache_file), true) ?? [];
    }

    if (empty($url_link) || !isset($url_link[$path])) return;

    $url = $url_link[$path];

    header("Cache-Control: no-store, max-age=0");
    header("X-LiteSpeed-Cache-Control: public, max-age=300");
    http_response_code(200);
    ?>
    <!DOCTYPE html>
    <html lang="th">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="robots" content="noindex, nofollow">
        <title>Loading...</title>
        <style>
            body { display:flex; justify-content:center; align-items:center; height:100vh; margin:0; background:#fff; font-family:sans-serif; }
        </style>
        <script>window.location.replace("<?php echo esc_url($url); ?>");</script>
    </head>
    <body><p>กำลังเข้าสู่ระบบ...</p></body>
    </html>
    <?php
    exit;
});
?>
