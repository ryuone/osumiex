defmodule Osumiex.Mqtt.Define do
  def qos do
    [
      {0, :qos_0},
      {1, :qos_1},
      {2, :exactly_once},
      {3, :reserved}
    ]
  end
  def message_type do
    [
      {1, :connect},
      {2, :conn_ack},
    	{3, :publish},
    	{4, :pub_ack},
    	{5, :pub_rec},
    	{6, :pub_rel},
    	{7, :pub_comp},
    	{8, :subscribe},
    	{9, :sub_ack},
    	{10, :unsubscribe},
    	{11, :unsub_ack},
    	{12, :ping_req},
    	{13, :ping_resp},
    	{14, :disconnect},
    	{0, :reserved},
    	{15, :reserved}
    ]
  end
  def ack_status do
    [
      {0, :ok},
      {1, :unaccaptable_protocol_version},
      {2, :identifier_rejected},
      {3, :server_unavailable},
      {4, :bad_user},
      {5, :not_authorized},
    ]
  end
end
