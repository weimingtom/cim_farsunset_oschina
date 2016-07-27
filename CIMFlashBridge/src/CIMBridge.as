package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.media.Sound;
	import flash.net.Socket;
	import flash.net.URLRequest;
	import flash.system.Security;
	import flash.utils.Timer;
	
	
	public class CIMBridge extends Sprite
	{
		internal var CIM_HOST:String = "127.0.0.1";
		internal var CIM_PORT:Number = 23456;
		internal const TIME_OUT :Number =10000;
		internal const RE_CONNECT_TIME :Number = 20000;
		internal var socket:Socket = new Socket(); 
		internal var froceOffline :Boolean = false;
		internal const MESSAGE_SEPARATE :String = '\b';
		/**
		 * 服务端心跳请求命令   
		 */
		internal  const CMD_HEARTBEAT_REQUEST:String="S_H_RQ";
		/**
		 * 客户端心跳响应命令   
		 */
		internal const  CMD_HEARTBEAT_RESPONSE:String ="C_H_RS"; 
		
		internal var mBuffer :String = '';
		
		public function CIMBridge()
		{
			
			ExternalInterface.addCallback("connect",connect);
			ExternalInterface.addCallback("bindAccount",bindAccount);
			ExternalInterface.addCallback("getOfflineMessage",getOfflineMessage);
			ExternalInterface.addCallback("logout",logout);
			ExternalInterface.addCallback("playSound",playSound);
			
			ExternalInterface.call("flashBridgeCreated");
			
		}
		public function connect(host:String,port:Number):void
		{	
			 
			CIM_HOST = host;
			CIM_PORT = port;
			var policyfile:String="xmlsocket://"+CIM_HOST+":"+CIM_PORT;
			Security.loadPolicyFile(policyfile);//加载安全策略文件，得到相应的返回才会创建连接
			socket.timeout = TIME_OUT;
			socket.addEventListener(Event.CONNECT,sessionCreated);//监听是否连接上服务器
			socket.addEventListener(Event.CLOSE,sessionClosed);//监听套接字连接是否关闭
			socket.addEventListener(IOErrorEvent.IO_ERROR,sessionFailed);//监听套接字连接是否失败
			socket.addEventListener(ProgressEvent.SOCKET_DATA,messageReceived); //监听服务器消息
			socket.connect(CIM_HOST,CIM_PORT);//连接服务器    
			
			
			var timer:Timer = new Timer(TIME_OUT, 1);
			timer.addEventListener(TimerEvent.TIMER, function():void{  
				if(socket.connected == false){
					sessionFailed(new IOErrorEvent(""));
				}
			});
			timer.start();
			
		}
		
		public function bindAccount(account:String,deviceId:String):void
		{
			var xml:String="<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
			xml+="<sent>";
			xml+="<key>client_bind</key>";   
			xml+="<data>";
			xml+="<account>"+account+"</account>";
			xml+="<deviceId>"+deviceId+"</deviceId>";
			xml+="<channel>browse</channel>";
			xml+="<device>Flash</device>";
			xml+="<version>2.0.0</version>";
			xml+="<osVersion>"+flash.system.Capabilities.os+"</osVersion>";
			xml+="</data>";
			xml+="</sent>";
			
			send(xml);
			
		}
		
		public function getOfflineMessage(account:String):void
		{
			
			var xml:String="<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
			xml+="<sent>";
			xml+="<key>client_get_offline_message</key>";   
			xml+="<data>";
			xml+="<account>"+account+"</account>";
			xml+="</data>";
			xml+="</sent>";
			send(xml);
			
		}
		
		public function logout():void
		{
			
			socket.close();
			
		}
		
		private function sessionCreated(event:Event):void
		{
			
			ExternalInterface.call("sessionCreated");
			froceOffline = false;
		}
		
		 
		
		private function sessionClosed(event:Event):void
		{
			ExternalInterface.call("sessionClosed");
			
			if(!froceOffline)
			{
				reconnection();
			}
		}
		 
		private function sessionFailed(event:Event):void
		{
			//每隔20秒重新连接
			
			ExternalInterface.call("sessionFailed");
			
			reconnection();
			
		}
		
		private function reconnection():void{
			var timer:Timer = new Timer(RE_CONNECT_TIME + Math.random() * 10, 1);
			timer.addEventListener(TimerEvent.TIMER, function():void{  
				connect(CIM_HOST,CIM_PORT);
			});
			timer.start();
		
		}
		
		
		internal function handleMessage(message:String):void{
		
			if(message.toUpperCase() == CMD_HEARTBEAT_REQUEST)
			{
				send(CMD_HEARTBEAT_RESPONSE);
				return;
			}
			
			
			var xml:XML=XML(message);
			if(xml.name()=="reply"){
				ExternalInterface.call("onReplyReceived",ReplyBody.mappingToJSON(xml));
			}
			if(xml.name()=="message"){
				
				
				if(xml["type"]=="999")
				{
					froceOffline = true;
				}
				
				ExternalInterface.call("onMessageReceived",Message.mappingToJSON(xml));
			}
		}
		
		/**接受服务器信息*/
		internal function messageReceived(event:ProgressEvent):void
		{
			
			mBuffer+=socket.readMultiByte(socket.bytesAvailable,"UTF-8");;
			if(mBuffer.charAt(mBuffer.length-1)!=MESSAGE_SEPARATE){
				
			   return ;
			   
			}else
			{
				var array:Array = mBuffer.split(MESSAGE_SEPARATE);
				for each(var message:String in array) {
					handleMessage(message);
				}
				
				mBuffer = "";
				
			}
			
		}
		
		
		/**发送数据到服务器*/
		internal function send(msg:String):void 
		{
			//新建一个ByteArray来存放数据
			socket.writeUTFBytes(msg+MESSAGE_SEPARATE);
			//调用flush方法发送信息
			socket.flush();
		} 
		
		public function playSound(name:String):void
		{
			internal var _sound:Sound = new Sound(new URLRequest(name));
			_sound.play(1);
		}
		
		 
		
	}
}