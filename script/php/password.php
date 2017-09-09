<?php
/**
 * Скрипт меняет пароль у юзера.
 *
 * @param $base_path
 * @param $user
 * @param $password
 */

/** @var modX $modx */

//
if (!empty($argv)) {
    $base_path = @$argv[1];
    $username = @$argv[2];
    $password = @$argv[3];
    $sudo = isset($argv[4]) ? $argv[4] : true;
}
if (empty($base_path) || empty($username) || empty($password)) {
    exit('ERROR: Bad params.' . PHP_EOL);
}

// Подключаем MODX
define('MODX_API_MODE', true);
if (file_exists($base_path . '/index.php')) {
    require_once $base_path . '/index.php';
}
if (!is_object($modx)) {
    exit('ERROR: Access denied.' . PHP_EOL);
}
$modx->getService('error', 'error.modError');
$modx->getRequest();
$modx->setLogLevel(modX::LOG_LEVEL_ERROR);
$modx->setLogTarget('FILE');
$modx->error->message = null;

//
if (!$user = $modx->getObject('modUser', array('username' => $username))) {
    $user = $modx->newObject('modUser');
    $user->fromArray(array(
        'username' => $username,
        'password' => $password,
        'active' => 1,
    ));
    if ($sudo) {
        $user->set('primary_group', true);
        $user->setSudo(1);
    }
    $profile = $modx->newObject('modUserProfile');
    $profile->fromArray(array(
        'fullname' => $user->get('username'),
        'email' => $user->get('username') . '@' . $user->get('username') . '.ru',
    ));
    $user->addOne($profile);
    $user->save();
} else {
    $user->changePassword($password, '', false);
}

exit('Done!');