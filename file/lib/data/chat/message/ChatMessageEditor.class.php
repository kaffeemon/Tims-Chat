<?php
namespace wcf\data\chat\message;

/**
 * Provides functions to edit chat messages.
 *
 * @author 	Tim Düsterhus
 * @copyright	2010-2012 Tim Düsterhus
 * @license	Creative Commons Attribution-NonCommercial-ShareAlike <http://creativecommons.org/licenses/by-nc-sa/3.0/legalcode>
 * @package	be.bastelstu.wcf.chat
 * @subpackage	data.chat.message
 */
class ChatMessageEditor extends \wcf\data\DatabaseObjectEditor {
	/**
	 * @see	\wcf\data\DatabaseObjectDecorator::$baseClass
	 */
	protected static $baseClass = '\wcf\data\chat\message\ChatMessage';
	
	
	/**
	 * Removes old messages.
	 *
	 * @param	integer	$lifetime	Delete messages older that this time.
	 * @return	integer			Number of deleted messages.
	 */
	public static function prune($lifetime = CHAT_ARCHIVETIME) {
		$baseClass = self::$baseClass;
		$sql = "SELECT
				".$baseClass::getDatabaseTableIndexName()."
			FROM
				".$baseClass::getDatabaseTableName()."
			WHERE
				time < ?";
		$stmt = \wcf\system\WCF::getDB()->prepareStatement($sql);
		$stmt->execute(array(TIME_NOW - $lifetime));
		$objectIDs = array();
		while ($objectIDs[] = $stmt->fetchColumn());
		
		return self::deleteAll($objectIDs);
	}
}
