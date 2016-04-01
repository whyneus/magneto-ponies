<?php

  $ch = curl_init('http://127.0.0.1:8080/customer/account/login/');
  curl_exec($ch);

  $info = curl_getinfo($ch);

// host[2]
  $host = explode("/", $info['redirect_url']);


  if ($info['http_code'] == 302) {
    curl_setopt($ch, CURLOPT_HTTPHEADER, array('Host: $host[2]'));
    curl_setopt

  } else {
    echo "no redirect";
  }

?>
