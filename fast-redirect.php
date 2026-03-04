<?php
/*
Plugin Name: Fast Redirect (PageSpeed Friendly)
Description: ระบบ Redirect ความเร็วสูง + ไม่กวนหน้าแรก + รองรับ Google
Version: 10.0 (Final)
*/
add_action('muplugins_loaded', function() {
    $path = rtrim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/');
    $routes = [
        '/login-2'      => 'https://member.ufavisions.com/',
        '/register-2'   => 'https://member.ufavisions.com/register',
        '/contact-us-2' => 'https://member.ufavisions.com/contact-us',
    ];
    if (!isset($routes[$path])) return;
    $url = $routes[$path];
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
