<?php
namespace wcf\acp\form;
use \wcf\system\exception\UserInputException;
use \wcf\system\language\I18nHandler;
use \wcf\system\WCF;

/**
 * Shows the chatroom add form.
 *
 * @author	Tim Düsterhus
 * @copyright	2010-2012 Tim Düsterhus
 * @license	Creative Commons Attribution-NonCommercial-ShareAlike <http://creativecommons.org/licenses/by-nc-sa/3.0/legalcode>
 * @package	be.bastelstu.wcf.chat
 * @subpackage	acp.form
 */
class ChatRoomAddForm extends ACPForm {
	/**
	 * @see	\wcf\acp\form\ACPForm::$activeMenuItem
	 */
	public $activeMenuItem = 'wcf.acp.menu.link.chat.room.add';
	
	/**
	 * @see	\wcf\page\AbstractPage::$neededPermissions
	 */
	public $neededPermissions = array('admin.content.chat.canAddRoom');
	
	/**
	 * Title of the room
	 * 
	 * @var	string
	 */
	public $title = '';
	
	/**
	 * Topic of the room
	 * 
	 * @var	string
	 */
	public $topic = '';
	
	/**
	 * @see	\wcf\page\AbstractPage::__construct()
	 */
	public function __construct() {
		$this->objectTypeID = \wcf\system\acl\ACLHandler::getInstance()->getObjectTypeID('be.bastelstu.wcf.chat.room');
		
		parent::__construct();
	}
	
	/**
	 * @see	\wcf\page\IPage::readParameters()
	 */
	public function readParameters() {
		parent::readParameters();

		I18nHandler::getInstance()->register('title');
		I18nHandler::getInstance()->register('topic');
	}
	
	/**
	 * @see	\wcf\form\IForm::readFormParameters()
	 */
	public function readFormParameters() {
		parent::readFormParameters();

		I18nHandler::getInstance()->readValues();

		if (I18nHandler::getInstance()->isPlainValue('title')) $this->title = I18nHandler::getInstance()->getValue('title');
		if (I18nHandler::getInstance()->isPlainValue('topic')) $this->topic = I18nHandler::getInstance()->getValue('topic');
	}
	
	/**
	 * @see	\wcf\form\IForm::validate()
	 */
	public function validate() {
		parent::validate();
		
		// validate title
		if (!I18nHandler::getInstance()->validateValue('title')) {
			throw new UserInputException('title');
		}
	}
	
	/**
	 * @see	\wcf\form\IForm::save()
	 */
	public function save() {
		parent::save();

		// save room
		$this->objectAction = new \wcf\data\chat\room\ChatRoomAction(array(), 'create', array('data' => array(
			'title' => $this->title,
			'topic' => $this->topic
		)));
		$this->objectAction->executeAction();
		$returnValues = $this->objectAction->getReturnValues();
		$chatRoomEditor = new \wcf\data\chat\room\ChatRoomEditor($returnValues['returnValues']);
		$roomID = $returnValues['returnValues']->roomID;
		
		if (!I18nHandler::getInstance()->isPlainValue('title')) {
			I18nHandler::getInstance()->save('title', 'wcf.chat.room.title'.$roomID, 'wcf.chat.room', \wcf\util\ChatUtil::getPackageID());
		
			// update title
			$chatRoomEditor->update(array(
				'title' => 'wcf.chat.room.title'.$roomID
			));
		}
		
		if (!I18nHandler::getInstance()->isPlainValue('topic')) {
			I18nHandler::getInstance()->save('topic', 'wcf.chat.room.topic'.$roomID, 'wcf.chat.room', \wcf\util\ChatUtil::getPackageID());
		
			// update topic
			$chatRoomEditor->update(array(
				'topic' => 'wcf.chat.room.topic'.$roomID
			));
		}
		
		\wcf\system\acl\ACLHandler::getInstance()->save($roomID, $this->objectTypeID);
		\wcf\system\chat\permission\ChatPermissionHandler::clearCache();
		
		$this->saved();
		
		// reset values
		$this->topic = $this->title = '';
		I18nHandler::getInstance()->disableAssignValueVariables();
		
		// show success
		WCF::getTPL()->assign(array(
			'success' => true
		));
	}
	
	/**
	 * @see	\wcf\page\IPage::assignVariables()
	 */
	public function assignVariables() {
		parent::assignVariables();
		
		I18nHandler::getInstance()->assignVariables();
		
		WCF::getTPL()->assign(array(
			'action' => 'add',
			'title' => $this->title,
			'topic' => $this->topic,
			'objectTypeID' => $this->objectTypeID
		));
	}
}
