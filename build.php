#!/usr/bin/env php
<?php
/**
 * Builds the Chat
 *
 * @author 	Tim Düsterhus
 * @copyright	2010-2012 Tim Düsterhus
 * @license	Creative Commons Attribution-NonCommercial-ShareAlike <http://creativecommons.org/licenses/by-nc-sa/3.0/legalcode>
 * @package	be.bastelstu.wcf.chat
 */
echo <<<EOT
Cleaning up
-----------

EOT;
	if (file_exists('package.xml.old')) {
		file_put_contents('package.xml', file_get_contents('package.xml.old'));
		unlink('package.xml.old');
	}
	if (file_exists('file.tar')) unlink('file.tar');
	if (file_exists('template.tar')) unlink('template.tar');
	if (file_exists('acptemplate.tar')) unlink('acptemplate.tar');
	foreach (glob('file/js/*.js') as $jsFile) unlink($jsFile);
	foreach (glob('file/style/*.css') as $cssFile) unlink($cssFile);
	if (file_exists('be.bastelstu.wcf.chat.tar')) unlink('be.bastelstu.wcf.chat.tar');
echo <<<EOT

Building JavaScript
-------------------

EOT;
foreach (glob('file/js/*.coffee') as $coffeeFile) {
	echo $coffeeFile."\n";
	passthru('coffee -cb '.escapeshellarg($coffeeFile), $code);
	if ($code != 0) exit($code);
}
echo <<<EOT

Building CSS
------------

EOT;
foreach (glob('file/style/*.scss') as $sassFile) {
	echo $sassFile."\n";
	passthru('scss '.escapeshellarg($sassFile).' '.escapeshellarg(substr($sassFile, 0, -4).'css'), $code);
	if ($code != 0) exit($code);
}
echo <<<EOT

Checking PHP for Syntax Errors
------------------------------

EOT;
	chdir('file');
	$check = null;
	$check = function ($folder) use (&$check) {
		if (is_file($folder)) {
			if (substr($folder, -4) === '.php') {
				passthru('php -l '.escapeshellarg($folder), $code);
				if ($code != 0) exit($code);
			}
			
			return;
		}
		$files = glob($folder.'/*');
		foreach ($files as $file) {
			$check($file);
		}
	};
	$check('.');
echo <<<EOT

Building file.tar
-----------------

EOT;
	passthru('tar cvf ../file.tar * --exclude=*.coffee --exclude=*.scss --exclude=.sass-cache', $code);
	if ($code != 0) exit($code);
echo <<<EOT

Building template.tar
---------------------

EOT;
	chdir('../template');
	passthru('tar cvf ../template.tar *', $code);
	if ($code != 0) exit($code);
echo <<<EOT

Building acptemplate.tar
------------------------

EOT;
	chdir('../acptemplate');
	passthru('tar cvf ../acptemplate.tar *', $code);
	if ($code != 0) exit($code);
echo <<<EOT

Building be.bastelstu.wcf.chat.tar
----------------------------------

EOT;
	chdir('..');
	file_put_contents('package.xml.old', file_get_contents('package.xml'));
	file_put_contents('package.xml', preg_replace('~<date>\d{4}-\d{2}-\d{2}</date>~', '<date>'.date('Y-m-d').'</date>', file_get_contents('package.xml')));
	passthru('tar cvf be.bastelstu.wcf.chat.tar * --exclude=*.old --exclude=file --exclude=template --exclude=acptemplate --exclude=build.php', $code);
	if (file_exists('package.xml.old')) {
		file_put_contents('package.xml', file_get_contents('package.xml.old'));
		unlink('package.xml.old');
	}
	if ($code != 0) exit($code);

if (file_exists('file.tar')) unlink('file.tar');
if (file_exists('template.tar')) unlink('template.tar');
if (file_exists('acptemplate.tar')) unlink('acptemplate.tar');
foreach (glob('file/js/*.js') as $jsFile) unlink($jsFile);
foreach (glob('file/style/*.css') as $cssFile) unlink($cssFile);
