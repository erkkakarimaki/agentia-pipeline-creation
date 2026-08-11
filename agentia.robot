*** Settings ***
Library                   QForce
Library                   QVision
Library                   Collections
Variables                 data.yaml
Suite Setup               Setup Browser
Suite Teardown            End suite

*** Variables ***
${BROWSER}                chrome
${login_url}              ${agentia_login_url}
${home_url}               ${login_url}

*** Test Cases ***
Create a Pipeline
    [Documentation]             This script will login to Agentia via Salesforce and Copado Okta.
    ...                         It will create a GitHub repository, Git and Sandbox connections.
    ...                         It will create a Pipeline and a sample Work Item.
    ...                         Data is populated from data.yaml file.
    [tags]                      Agentia Pipeline

    Appstate                    Home

    # Open Pipelines
    Navigate to Pipelines       login_username=${agentia_login_username}
    VerifyText                  Welcome to Agentia™ Pipeline

    # Create a new GitHub repository
    Create new GitHub repository
    ...                        repository_name=${git_repository_name}
    ...                        repository_email=${git_repository_email}

    # Add Git connection
    Add new GitHub Repository Connection Authenticated
    ...                         repository_type=${git_repository_provider}
    ...                         repository_name=${git_repository_name}
    ...                         repository_username=${git_repository_username}

    # Add Salesforce connections for Dev, QA, Prod
    FOR  ${instance}  IN  @{sandboxes}
        Log  Adding a new sandbox connection for ${instance}[short_name]  console=True
        Add new Salesforce Sandbox Connection
        ...                         sandbox_name=${instance}[name]
        ...                         sandbox_username=${instance}[username]
        ...                         sandbox_password=${${instance}[password_variable]}
    END

    # Create a new Pipeline
    ${envs}=  Create List
    FOR  ${instance}  IN  @{sandboxes}
        VAR  &{environment}  name=${instance}[short_name]  env=${instance}[name]
        Append To List  ${envs}  ${environment}
    END

    Create new Pipeline
    ...                         pipeline_name=${agentia_pipeline_name}
    ...                         repository_name=${git_repository_name}
    ...                         environments=${envs}

    SetConfig                   SearchDirection             closest

    # Create new Work Item(s)
    FOR  ${item}  IN  @{workitems}
        Log                         Creating a Work Item: ${item}[title]
        ClickText                   Work Manager
        ClickText                   New Work Item

        TypeText                    Title                       ${item}[title]
        TypeText                    Issue                       ${item}[issue]
        TypeText                    Description                 ${item}[description]
        DropDown                    Pipeline                    ${agentia_pipeline_name}
        # Note, initial stage org already selected.
        ClickText                   New Work Item               anchor=Cancel
    END

    Log                        All done.  console=True

*** Keywords ***
Setup Browser
    # Setting search order is not really needed here, but given as an example
    # if you need to use multiple libraries containing keywords with duplicate names
    Set Library Search Order                          QForce    QWeb    QVision
    Open Browser          about:blank                 ${BROWSER}
    SetConfig             LineBreak                   ${EMPTY}
    Evaluate              random.seed()               random                 # initialize random generator
    SetConfig             DefaultTimeout              45s                    #sometimes salesforce is slow
    # adds a delay of 0.3 between keywords. This is helpful in cloud with limited resources.
    SetConfig             Delay                       0.3

End suite
    Close All Browsers

Navigate to Pipelines
    [Arguments]    ${login_username}
    ClickText                 Open  anchor=Pipeline  doubleclick=True
    ${double_login}=          IsText    Connect with Salesforce  2
    IF  ${double_login}
        ClickText             Connect with Salesforce
        ClickText             Use Custom Domain
        TypeText              Custom Domain  copado
        ClickText             Continue
    ELSE
        ClickText                 Select    anchor=${login_username}  tag=button
    END

Login
    [Documentation]       Login to Salesforce instance. Takes instance_url, username and password as
    ...                   arguments. Uses values given in Copado Robotic Testing's variables section by default.
    ...                   Note: this uses Okta SSO MFA to login. Modify the keyword to satisfy your login process.
    [Arguments]           ${sf_instance_url}=${login_url}    ${sf_username}=${agentia_login_username}   ${sf_password}=${agentia_login_password}
    GoTo                  ${sf_instance_url}
    ClickText             Continue with Salesforce
    ClickText             Use Custom Domain
    TypeText              Custom Domain  copado
    ClickText             Continue

    TypeText              Username                ${sf_username}             delay=1
    TypeSecret            Password                ${sf_password}
    ClickText             Sign In
    ClickText             Send Push

    # We'll check if variable ${secret} is given. If yes, fill the MFA dialog.
    # If not, MFA is not expected.
    # ${secret} is ${None} unless specifically given.
    ${MFA_needed}=       Run Keyword And Return Status          Should Not Be Equal    ${None}       ${secret}
    Run Keyword If       ${MFA_needed}               Fill MFA   ${sf_username}         ${secret}    ${sf_instance_url}

Fill MFA
    [Documentation]      Gets the MFA OTP code and fills the verification dialog (if needed)
    [Arguments]          ${sf_username}=${agentia_login_username}    ${mfa_secret}=${secret}  ${sf_instance_url}=${login_url}
    ${mfa_code}=         GetOTP    ${sf_username}   ${mfa_secret}   ${sf_instance_url}
    TypeSecret           Verification Code       ${mfa_code}
    ClickText            Verify

Home
    [Documentation]       Example appstate: Navigate to homepage, login if needed
    GoTo                  ${home_url}
    ${login_status} =     IsText                      Continue with Salesforce    2
    Run Keyword If        ${login_status}             Login
    VerifyText            Welcome

###########
## Repository

Create new GitHub repository
    [Documentation]      Create a new GitHub repository
    [Arguments]          ${repository_name}  ${repository_email}

    Log                  \nCreating a GitHub repository: ${repository_name}  console=True
    OpenWindow
    SwitchWindow         NEW

    GoTo                 https://github.com

    # Note, already signed in to Okta.

    ClickText            Sign in
    ClickText            Continue with Google
    TypeText             Email or phone              ${repository_email}
    ClickText            Next

    VerifyText           Verify it

    ClickText            Continue
    QVision.ClickText    Use Chromium without an account

    ${otp}=              GetOtp                      ${repository_email}   ${github_totp}
    TypeText             app_otp                     ${otp}                tag=input

    ${dashboard}=        IsText                      Dashboard             2
    IF                   ${dashboard}
        ClickText        Dashboard
    END

    ClickText            New
    TypeText             Repository name*            ${repository_name}
    ClickText            Public                      tag=button

    ClickText            Private
    ClickItem            add-readme                  tag=button
    ClickText            Create repository

    VerifyText           Initial commit
    CloseWindow
    SwitchWindow         1

############
## Connections

Navigate to Connections
    [Documentation]            Navigate to Pipeline Connections
    [Arguments]                ${connection_type}
    Log                        Navigating to Agentia Pipeline Connections  console=True
    GoTo                       https://us.pipeline.copado.com/app/#/Home
    ClickText                  Connections
    ClickText                  Add Connection
    UseModal                   On
    DropDown                   Type                        ${connection_type}

Add new GitHub Repository Connection
    [Documentation]            Create a new GitHub Connection
    [Arguments]                ${repository_name}          ${repository_username}

    Log                        Creating a GitHub Repository Connection  console=True
    Navigate to Connections    connection_type=GitHub
    TypeText                   Name                        ${repository_name}
    UseModal                   Off
    ClickText                  Authorize
    SwitchWindow               NEW
    ClickText                  Continue with Google
    TypeText                   Email or phone              ${Agentia_US.username}
    ClickText                  Next
    VerifyText                 Verify it's you
    ClickText                  Continue

    SwitchWindow               1
    ClickText                  select repository
    DropDown                   Git Repo Url                https://github.com/${repository_username}/${repository_name}.git

    ClickText                  Save

Add new GitHub Repository Connection Authenticated
    [Documentation]            Create a new GitHub Connection
    ...                        when there is already an active authenticated session
    ...                        with GitHub.
    [Arguments]                ${repository_type}    ${repository_name}          ${repository_username}

    Log                        Creating a GitHub Repository Connection  console=True
    Navigate to Connections    connection_type=${repository_type}
    TypeText                   Name                        ${repository_name}
    ClickText                  Authorize                   delay=2
    UseModal                   Off
    VerifyText                 Please select a git repository before this org can be used.

    SwitchWindow               1
    ClickText                  select repository
    DropDown                   Git Repo Url                https://github.com/${repository_username}/${repository_name}.git

    ClickText                  Save
    VerifyText                 Success
    ClickText                  Test connection
    VerifyText                 Success

Add new GitHub Repository Connection Un-Authenticated
    [Documentation]            Create a new GitHub Connection
    ...                        when there is no active authenticated session
    ...                        with GitHub.
    [Arguments]                ${repository_name}          ${repository_username}

    Navigate to Connections    connection_type=GitHub
    TypeText                   Name                        ${repository_name}
    ClickText                  Authorize
    UseModal                   Off
    VerifyText                 Please select a git repository before this org can be used.
    SwitchWindow               NEW
    ClickText                  Continue with Google
    TypeText                   Email or phone              ${Agentia_US.username}
    ClickText                  Next
    VerifyText                 Verify it's you
    ClickText                  Continue

    SwitchWindow               1
    ClickText                  select repository
    DropDown                   Git Repo Url                https://github.com/${repository_username}/${repository_name}.git

    ClickText                  Save
    VerifyText                 Success

Add new Salesforce Sandbox Connection
    [Documentation]            Create a new Salesforce Sandbox Connection
    [Arguments]                ${sandbox_name}             ${sandbox_username}         ${sandbox_password}

    Navigate to Connections    connection_type=Salesforce Org
    TypeText                   Name                        ${sandbox_name}
    DropDown                   Environment                 Sandbox
    ClickText                  Authorize
    SwitchWindow               2

    TypeText                   Username                    ${sandbox_username}
    ClickText                  Log in to Sandbox
    TypeText                   Password                    ${sandbox_password}
    ClickText                  Log in to Sandbox

    SwitchWindow               1
    ClickText                  Save
    Sleep                      3

    ${re-authorize}=           IsText                      Authorize                   partial_match=False  timeout=5

    WHILE  ${re-authorize}                        limit=3
        ClickText              Authorize
        SwitchWindow           NEW
        TypeText               Username                    ${sandbox_username}
        ClickText              Log in to Sandbox
        TypeText               Password                    ${sandbox_password}
        ClickText              Log in to Sandbox
        SwitchWindow           1
        Sleep                  3
        ${re-authorize}=           IsText                      Authorize                   partial_match=False
    END

    ClickText                  Test connection
    VerifyText                 Success
    ClickText                  Save

##################
## Pipelines

Add Environment
    [Documentation]    Fill in the environment details
    [Arguments]        ${index}                ${environment}

    VAR                ${anchor_text}          Environment ${index}

    IF                 ${index} >= 3
        ClickText      Add Environment
        Scroll         //html
    END

    SetConfig          SearchDirection  down

    TypeText           environment name ...    ${environment}[name]    tag=input  anchor=${anchor_text}
    ClickItem          select                  tag=input               anchor=${anchor_text}
    ClickText          ${environment}[env]

Create new Pipeline
    [Documentation]    Create a new Pipeline
    [Arguments]        ${pipeline_name}        ${repository_name}      ${environments}

    Log                Creating a New Pipeline: ${pipeline_name}  console=True
    ClickText          Pipelines
    ClickText          New Pipeline

    UseModal           On
    TypeText           Name                    ${pipeline_name}
    ClickItem          select                  tag=input
    ClickText          ${repository_name}

    FOR                ${index}                ${env}                  IN ENUMERATE             @{environments}
        ${i}=          Evaluate                ${index}+1
        Add Environment                        ${i}                    ${env}
    END

    ClickText          Save
    UseModal           Off
