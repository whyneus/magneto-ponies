<?php
$proxy = new SoapClient('http://magento-cloud.co.uk/api/?wsdl');
$sessionId = $proxy->login('apiadmin', 'password');



for($i = 1; $i < 2; ++$i) {
// Create new customer
$newCustomer = array(
    'firstname'  => "First{$i}",
    'lastname'   => "Last{$i}",
    'email'      => "first{$i}@test.com",
    'password'   => 'password',
    'store_id'   => 1,
    'website_id' => 1
);

$newCustomerId = $proxy->call($sessionId, 'customer.create', array($newCustomer));

//Create new customer address
$newCustomerAddress = array(
    'firstname'  => "First{$i}",
    'lastname'   => "Last{$i}",
    'country_id' => 'GB',
    'region_id'  => '0',
    'region'     => 'London',
    'city'       => 'Hayes',
    'street'     => array('93 Millington Road','HPH'),
    'telephone'  => '02087342700',
    'postcode'   => 'UB34AZ',

    'is_default_billing'  => true,
    'is_default_shipping' => true
);

$newAddressId = $proxy->call($sessionId, 'customer_address.create', array($newCustomerId, $newCustomerAddress));
}
?>
