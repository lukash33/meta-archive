set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_050100 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2016.08.24'
,p_default_workspace_id=>1720675616047831
);
end;
/
prompt  WORKSPACE 1720675616047831
--
-- Workspace, User Group, User, and Team Development Export:
--   Date and Time:   00:57 Friday February 10, 2017
--   Exported By:     METAARCHIVE
--   Export Type:     Workspace Export
--   Version:         5.1.0.00.45
--   Instance ID:     220182249059055
--
-- Import:
--   Using Instance Administration / Manage Workspaces
--   or
--   Using SQL*Plus as the Oracle user APEX_050100
 
begin
    wwv_flow_api.set_security_group_id(p_security_group_id=>1720675616047831);
end;
/
----------------
-- W O R K S P A C E
-- Creating a workspace will not create database schemas or objects.
-- This API creates only the meta data for this APEX workspace
prompt  Creating workspace META...
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
end;
/
begin
wwv_flow_fnd_user_api.create_company (
  p_id => 1720707203047853
 ,p_provisioning_company_id => 1720675616047831
 ,p_short_name => 'META'
 ,p_display_name => 'META'
 ,p_first_schema_provisioned => 'MA'
 ,p_company_schemas => 'MA'
 ,p_expire_fnd_user_accounts => 'N'
 ,p_fnd_user_max_login_failures => 15
 ,p_account_status => 'ASSIGNED'
 ,p_allow_plsql_editing => 'Y'
 ,p_allow_app_building_yn => 'Y'
 ,p_allow_packaged_app_ins_yn => 'Y'
 ,p_allow_sql_workshop_yn => 'Y'
 ,p_allow_websheet_dev_yn => 'Y'
 ,p_allow_team_development_yn => 'N'
 ,p_allow_to_be_purged_yn => 'N'
 ,p_allow_restful_services_yn => 'Y'
 ,p_source_identifier => 'META'
 ,p_path_prefix => 'META'
 ,p_files_version => 1
 ,p_max_session_idle_sec => 36000
 ,p_workspace_image => wwv_flow_api.g_varchar2_table
);
end;
/
----------------
-- G R O U P S
--
prompt  Creating Groups...
begin
wwv_flow_api.create_user_groups (
  p_id => 1850361316196493,
  p_GROUP_NAME => 'OAuth2 Client Developer',
  p_SECURITY_GROUP_ID => 10,
  p_GROUP_DESC => 'Users authorized to register OAuth2 Client Applications');
end;
/
begin
wwv_flow_api.create_user_groups (
  p_id => 1850213438196493,
  p_GROUP_NAME => 'RESTful Services',
  p_SECURITY_GROUP_ID => 10,
  p_GROUP_DESC => 'Users authorized to use RESTful Services with this workspace');
end;
/
begin
wwv_flow_api.create_user_groups (
  p_id => 1850179903196489,
  p_GROUP_NAME => 'SQL Developer',
  p_SECURITY_GROUP_ID => 10,
  p_GROUP_DESC => 'Users authorized to use SQL Developer with this workspace');
end;
/
prompt  Creating group grants...
----------------
-- U S E R S
-- User repository for use with APEX cookie-based authentication.
--
prompt  Creating Users...
begin
wwv_flow_fnd_user_api.create_fnd_user (
  p_user_id                      => '1720559541047831',
  p_user_name                    => 'METAARCHIVE',
  p_first_name                   => 'Sergey',
  p_last_name                    => 'Lukashevich',
  p_description                  => '',
  p_email_address                => 'gnu.oracle@gmail.com',
  p_web_password                 => 'C3D94C560F27C5A04192CE317067F123E60E0F6B',
  p_web_password_format          => '5;2;10000',
  p_group_ids                    => '',
  p_developer_privs              => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
  p_default_schema               => 'MA',
  p_account_locked               => 'N',
  p_account_expiry               => to_date('201702090000','YYYYMMDDHH24MI'),
  p_failed_access_attempts       => 0,
  p_change_password_on_first_use => 'N',
  p_first_password_use_occurred  => 'Y',
  p_allow_app_building_yn        => 'Y',
  p_allow_sql_workshop_yn        => 'Y',
  p_allow_websheet_dev_yn        => 'Y',
  p_allow_team_development_yn    => 'Y',
  p_allow_access_to_schemas      => 'MA');
end;
/
prompt Check Compatibility...
begin
-- This date identifies the minimum version required to import this file.
wwv_flow_team_api.check_version(p_version_yyyy_mm_dd=>'2010.05.13');
end;
/
 
begin wwv_flow.g_import_in_progress := true; wwv_flow.g_user := USER; end; 
/
 
--
prompt ...news
--
begin
null;
end;
/
--
prompt ...links
--
begin
null;
end;
/
--
prompt ...bugs
--
begin
null;
end;
/
--
prompt ...events
--
begin
null;
end;
/
--
prompt ...features
--
begin
null;
end;
/
--
prompt ...tasks
--
begin
wwv_flow_team_api.create_task (
  p_id => 22746529914126202 + wwv_flow_team_api.g_id_offset
 ,p_friendly_id => 1
 ,p_task_name => 'Select colors from the list - like google and yandex do'
 ,p_task_status => 70
 ,p_task_tags => 'color'
 ,p_application_id => 101
 ,p_created_by => 'METAARCHIVE'
 ,p_created_on => to_date('20170117200544','YYYYMMDDHH24MISS')
 ,p_updated_by => 'APEX_050100'
 ,p_updated_on => to_date('20170209234020','YYYYMMDDHH24MISS')
 ,p_page_id => 1
);
wwv_flow_team_api.create_task (
  p_id => 22746740887130848 + wwv_flow_team_api.g_id_offset
 ,p_friendly_id => 2
 ,p_task_name => 'GPS: Google Maps javascript API - geolocation - geocoding (forward/reverse)'
 ,p_task_status => 0
 ,p_task_tags => 'gps, exif'
 ,p_application_id => 101
 ,p_created_by => 'METAARCHIVE'
 ,p_created_on => to_date('20170117200630','YYYYMMDDHH24MISS')
 ,p_updated_by => 'APEX_050100'
 ,p_updated_on => to_date('20170209234020','YYYYMMDDHH24MISS')
 ,p_page_id => 1
);
end;
/
--
prompt ...feedback
--
begin
null;
end;
/
--
prompt ...task defaults
--
begin
null;
end;
/
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false));
commit;
end;
/
set verify on feedback on define on
prompt  ...done
