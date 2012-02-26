<?php
namespace wcf\system\chat\permission;
use \wcf\system\acl\ACLHandler;
use \wcf\system\package\PackageDependencyHandler;
use \wcf\system\WCF;

/**
 * Handles chat-permissions.
 *
 * @author 	Tim Düsterhus, Marcel Werk
 * @copyright	2010-2012 WoltLab GmbH
 * @license	GNU Lesser General Public License <http://opensource.org/licenses/lgpl-license.php>
 * @package	timwolla.wcf.chat
 * @subpackage	system.chat.permissions
 */
class ChatPermissionHandler extends \wcf\system\SingletonFactory {
	protected $chatPermissions = array();
	
	/**
	 * @see	\wcf\system\SingletonFactory::init()
	 */
	protected function init() {
		$packageID = PackageDependencyHandler::getPackageID('timwolla.wcf.chat');
		$ush = \wcf\system\user\storage\UserStorageHandler::getInstance();
		// TODO: get groups permissions
		
		// get user permissions
		if (WCF::getUser()->userID) {
			// get data from storage
			$ush->loadStorage(array(WCF::getUser()->userID), $packageID);
					
			// get ids
			$data = $ush->getStorage(array(WCF::getUser()->userID), 'chatUserPermissions', $packageID);
				
			// cache does not exist or is outdated
			if ($data[WCF::getUser()->userID] === null) {
				$userPermissions = array();
				
				$conditionBuilder = new \wcf\system\database\util\PreparedStatementConditionBuilder();
				$conditionBuilder->add('acl_option.packageID IN (?)', array(PackageDependencyHandler::getDependencies()));
				$conditionBuilder->add('acl_option.objectTypeID = ?', array(ACLHandler::getInstance()->getObjectTypeID('timwolla.wcf.chat.room')));
				$conditionBuilder->add('option_to_user.optionID = acl_option.optionID');
				$conditionBuilder->add('option_to_user.userID = ?', array(WCF::getUser()->userID));
				$sql = "SELECT		option_to_user.objectID AS roomID, option_to_user.optionValue,
							acl_option.optionName AS permission
					FROM		wcf".WCF_N."_acl_option acl_option,
							wcf".WCF_N."_acl_option_to_user option_to_user
							".$conditionBuilder;
				$statement = WCF::getDB()->prepareStatement($sql);
				$statement->execute($conditionBuilder->getParameters());
				while ($row = $statement->fetchArray()) {
					$userPermissions[$row['roomID']][$row['permission']] = $row['optionValue'];
				}
				
				// update cache
				$ush->update(WCF::getUser()->userID, 'chatUserPermissions', serialize($userPermissions), $packageID);
			}
			else {
				$userPermissions = unserialize($data[WCF::getUser()->userID]);
			}
			
			foreach ($userPermissions as $roomID => $permissions) {
				foreach ($permissions as $name => $value) {
					$this->chatPermissions[$roomID][$name] = $value;
				}
			}
		}
	}
	
	/**
	 * Fetches the given permission for the given room
	 *
	 * @param	\wcf\data\chat\room\ChatRoom	$room
	 * @param	string				$permission
	 * @return	boolean
	 */
	public function getPermission(\wcf\data\chat\room\ChatRoom $room, $permission) {
		if (!isset($this->chatPermissions[$room->roomID][$permission])) return true;
		return (boolean) $this->chatPermissions[$room->roomID][$permission];
	}
	
	/**
	 * Clears the cache.
	 */
	public static function clearCache() {
		$packageID = PackageDependencyHandler::getPackageID('timwolla.wcf.chat');
		$ush = \wcf\system\user\storage\UserStorageHandler::getInstance();
		
		$ush->resetAll('chatUserPermissions', $packageID);
	}
}