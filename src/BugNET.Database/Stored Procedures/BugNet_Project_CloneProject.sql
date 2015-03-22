﻿CREATE PROCEDURE [dbo].[BugNet_Project_CloneProject] 
(
  @ProjectId INT,
  @ProjectName NVarChar(256),
  @CloningUserName VARCHAR(75) = NULL
)
AS

DECLARE
	@CreatorUserId UNIQUEIDENTIFIER

SET NOCOUNT OFF

SET @CreatorUserId = (SELECT ProjectCreatorUserId FROM BugNet_Projects WHERE ProjectId = @ProjectId)

IF(@CloningUserName IS NOT NULL OR LTRIM(RTRIM(@CloningUserName)) != '')
	EXEC dbo.BugNet_User_GetUserIdByUserName @UserName = @CloningUserName, @UserId = @CreatorUserId OUTPUT

-- Copy Project
INSERT BugNet_Projects
(
  ProjectName,
  ProjectCode,
  ProjectDescription,
  AttachmentUploadPath,
  DateCreated,
  ProjectDisabled,
  ProjectAccessType,
  ProjectManagerUserId,
  ProjectCreatorUserId,
  AllowAttachments,
  SvnRepositoryUrl 
)
SELECT
  @ProjectName,
  ProjectCode,
  ProjectDescription,
  AttachmentUploadPath,
  GetDate(),
  ProjectDisabled,
  ProjectAccessType,
  ProjectManagerUserId,
  @CreatorUserId,
  AllowAttachments,
  SvnRepositoryUrl
FROM 
  BugNet_Projects
WHERE
  ProjectId = @ProjectId
  
DECLARE @NewProjectId INT
SET @NewProjectId = SCOPE_IDENTITY()

-- Copy Milestones
INSERT BugNet_ProjectMilestones
(
  ProjectId,
  MilestoneName,
  MilestoneImageUrl,
  SortOrder,
  DateCreated,
  MilestoneDueDate,
  MilestoneReleaseDate,
  MilestoneNotes,
  MilestoneCompleted
)
SELECT
  @NewProjectId,
  MilestoneName,
  MilestoneImageUrl,
  SortOrder,
  GetDate(),
  MilestoneDueDate,
  MilestoneReleaseDate,
  MilestoneNotes,
  MilestoneCompleted
FROM
  BugNet_ProjectMilestones
WHERE
  ProjectId = @ProjectId  

-- Copy Project Members
INSERT BugNet_UserProjects
(
  UserId,
  ProjectId,
  DateCreated
)
SELECT
  UserId,
  @NewProjectId,
  GetDate()
FROM
  BugNet_UserProjects
WHERE
  ProjectId = @ProjectId

-- Copy Project Roles
INSERT BugNet_Roles
( 
	ProjectId,
	RoleName,
	RoleDescription,
	AutoAssign
)
SELECT 
	@NewProjectId,
	RoleName,
	RoleDescription,
	AutoAssign
FROM
	BugNet_Roles
WHERE
	ProjectId = @ProjectId

CREATE TABLE #OldRoles
(
  OldRowNumber INT IDENTITY,
  OldRoleId INT,
)

INSERT #OldRoles
(
  OldRoleId
)
SELECT
	RoleId
FROM
	BugNet_Roles
WHERE
	ProjectId = @ProjectId
ORDER BY 
	RoleId

CREATE TABLE #NewRoles
(
  NewRowNumber INT IDENTITY,
  NewRoleId INT,
)

INSERT #NewRoles
(
  NewRoleId
)
SELECT
	RoleId
FROM
	BugNet_Roles
WHERE
	ProjectId = @NewProjectId
ORDER BY 
	RoleId

INSERT BugNet_UserRoles
(
	UserId,
	RoleId
)
SELECT 
	UserId,
	RoleId = NewRoleId
FROM 
	#OldRoles 
INNER JOIN #NewRoles ON  OldRowNumber = NewRowNumber
INNER JOIN BugNet_UserRoles UR ON UR.RoleId = OldRoleId

-- Copy Role Permissions
INSERT BugNet_RolePermissions
(
   PermissionId,
   RoleId
)
SELECT Perm.PermissionId, NewRoles.RoleId
FROM BugNet_RolePermissions Perm
INNER JOIN BugNet_Roles OldRoles ON Perm.RoleId = OldRoles.RoleID
INNER JOIN BugNet_Roles NewRoles ON NewRoles.RoleName = OldRoles.RoleName
WHERE OldRoles.ProjectId = @ProjectId 
	  and NewRoles.ProjectId = @NewProjectId


-- Copy Custom Fields
INSERT BugNet_ProjectCustomFields
(
  ProjectId,
  CustomFieldName,
  CustomFieldRequired,
  CustomFieldDataType,
  CustomFieldTypeId
)
SELECT
  @NewProjectId,
  CustomFieldName,
  CustomFieldRequired,
  CustomFieldDataType,
  CustomFieldTypeId
FROM
  BugNet_ProjectCustomFields
WHERE
  ProjectId = @ProjectId
  
-- Copy Custom Field Selections
CREATE TABLE #OldCustomFields
(
  OldRowNumber INT IDENTITY,
  OldCustomFieldId INT,
)
INSERT #OldCustomFields
(
  OldCustomFieldId
)
SELECT
	CustomFieldId
FROM
  BugNet_ProjectCustomFields
WHERE
  ProjectId = @ProjectId
ORDER BY CustomFieldId

CREATE TABLE #NewCustomFields
(
  NewRowNumber INT IDENTITY,
  NewCustomFieldId INT,
)

INSERT #NewCustomFields
(
  NewCustomFieldId
)
SELECT
  CustomFieldId
FROM
  BugNet_ProjectCustomFields
WHERE
  ProjectId = @NewProjectId
ORDER BY CustomFieldId

INSERT BugNet_ProjectCustomFieldSelections
(
	CustomFieldId,
	CustomFieldSelectionValue,
	CustomFieldSelectionName,
	CustomFieldSelectionSortOrder
)
SELECT 
	CustomFieldId = NewCustomFieldId,
	CustomFieldSelectionValue,
	CustomFieldSelectionName,
	CustomFieldSelectionSortOrder
FROM 
	#OldCustomFields 
INNER JOIN #NewCustomFields ON  OldRowNumber = NewRowNumber
INNER JOIN BugNet_ProjectCustomFieldSelections CFS ON CFS.CustomFieldId = OldCustomFieldId

-- Copy Project Mailboxes
INSERT BugNet_ProjectMailBoxes
(
  MailBox,
  ProjectId,
  AssignToUserId,
  IssueTypeId,
  CategoryId
)
SELECT
  Mailbox,
  @NewProjectId,
  AssignToUserId,
  IssueTypeId,
  CategoryId
FROM
  BugNet_ProjectMailBoxes
WHERE
  ProjectId = @ProjectId

-- Copy Categories
INSERT BugNet_ProjectCategories
(
  ProjectId,
  CategoryName,
  ParentCategoryId
)
SELECT
  @NewProjectId,
  CategoryName,
  ParentCategoryId
FROM
  BugNet_ProjectCategories
WHERE
  ProjectId = @ProjectId AND Disabled = 0 


CREATE TABLE #OldCategories
(
  OldRowNumber INT IDENTITY,
  OldCategoryId INT,
)

INSERT #OldCategories
(
  OldCategoryId
)
SELECT
  CategoryId
FROM
  BugNet_ProjectCategories
WHERE
  ProjectId = @ProjectId AND Disabled = 0
ORDER BY CategoryId

CREATE TABLE #NewCategories
(
  NewRowNumber INT IDENTITY,
  NewCategoryId INT,
)

INSERT #NewCategories
(
  NewCategoryId
)
SELECT
  CategoryId
FROM
  BugNet_ProjectCategories
WHERE
  ProjectId = @NewProjectId AND Disabled = 0
ORDER BY CategoryId

UPDATE BugNet_ProjectCategories SET
  ParentCategoryId = NewCategoryId
FROM
  #OldCategories INNER JOIN #NewCategories ON OldRowNumber = NewRowNumber
WHERE
  ProjectId = @NewProjectId
  And ParentCategoryId = OldCategoryId 

-- Copy Status's
INSERT BugNet_ProjectStatus
(
  ProjectId,
  StatusName,
  StatusImageUrl,
  SortOrder,
  IsClosedState
)
SELECT
  @NewProjectId,
  StatusName,
  StatusImageUrl,
  SortOrder,
  IsClosedState
FROM
  BugNet_ProjectStatus
WHERE
  ProjectId = @ProjectId 
 
-- Copy Priorities
INSERT BugNet_ProjectPriorities
(
  ProjectId,
  PriorityName,
  PriorityImageUrl,
  SortOrder
)
SELECT
  @NewProjectId,
  PriorityName,
  PriorityImageUrl,
  SortOrder
FROM
  BugNet_ProjectPriorities
WHERE
  ProjectId = @ProjectId 

-- Copy Resolutions
INSERT BugNet_ProjectResolutions
(
  ProjectId,
  ResolutionName,
  ResolutionImageUrl,
  SortOrder
)
SELECT
  @NewProjectId,
  ResolutionName,
  ResolutionImageUrl,
  SortOrder
FROM
  BugNet_ProjectResolutions
WHERE
  ProjectId = @ProjectId
 
-- Copy Issue Types
INSERT BugNet_ProjectIssueTypes
(
  ProjectId,
  IssueTypeName,
  IssueTypeImageUrl,
  SortOrder
)
SELECT
  @NewProjectId,
  IssueTypeName,
  IssueTypeImageUrl,
  SortOrder
FROM
  BugNet_ProjectIssueTypes
WHERE
  ProjectId = @ProjectId

-- Copy Project Notifications
INSERT BugNet_ProjectNotifications
(
  ProjectId,
  UserId
)
SELECT
  @NewProjectId,
  UserId
FROM
  BugNet_ProjectNotifications
WHERE
  ProjectId = @ProjectId

-- Copy Project Defaults
INSERT INTO BugNet_DefaultValues
    ([ProjectId]
    ,[DefaultType]
    ,[StatusId]
    ,[IssueOwnerUserId]
    ,[IssuePriorityId]
    ,[IssueAffectedMilestoneId]
    ,[IssueAssignedUserId]
    ,[IssueVisibility]
    ,[IssueCategoryId]
    ,[IssueDueDate]
    ,[IssueProgress]
    ,[IssueMilestoneId]
    ,[IssueEstimation]
    ,[IssueResolutionId]
    ,[OwnedByNotify]
    ,[AssignedToNotify])
SELECT
    @NewProjectId,
    DefaultType,
    StatusId,
    IssueOwnerUserId,
    IssuePriorityId,
    IssueAffectedMilestoneId,
    IssueAssignedUserId,
    IssueVisibility,
    IssueCategoryId,
    IssueDueDate,
    IssueProgress, 
    IssueMilestoneId,
    IssueEstimation,
    IssueResolutionId, 
    OwnedByNotify, 
    AssignedToNotify
FROM
	BugNet_DefaultValues
WHERE
	ProjectId = @ProjectId

-- Update Default Values with new value keys
UPDATE BugNet_DefaultValues  SET
	DefaultType = (SELECT IssueTypeId FROM BugNet_ProjectIssueTypes WHERE ProjectId = @NewProjectId AND IssueTypeName = (SELECT IssueTypeName FROM BugNet_ProjectIssueTypes WHERE IssueTypeId = BugNet_DefaultValues.DefaultType)),
	StatusId =  (SELECT StatusId FROM BugNet_ProjectStatus WHERE ProjectId = @NewProjectId AND StatusName = (SELECT StatusName FROM BugNet_ProjectStatus WHERE StatusId = BugNet_DefaultValues.StatusId)),
	IssuePriorityId =  (SELECT PriorityId FROM BugNet_ProjectPriorities WHERE ProjectId = @NewProjectId AND PriorityName = (SELECT PriorityName FROM BugNet_ProjectPriorities WHERE PriorityId = BugNet_DefaultValues.IssuePriorityId)),
	IssueAffectedMilestoneId = (SELECT MilestoneId FROM BugNet_ProjectMilestones WHERE ProjectId = @NewProjectId AND MilestoneName = (SELECT MilestoneName FROM BugNet_ProjectMilestones WHERE MilestoneId = BugNet_DefaultValues.IssueAffectedMilestoneId)),
	IssueCategoryId = (SELECT CategoryId FROM BugNet_ProjectCategories WHERE ProjectId = @NewProjectId AND CategoryName = (SELECT CategoryName FROM BugNet_ProjectCategories WHERE CategoryId = BugNet_DefaultValues.IssueCategoryId)),
	IssueMilestoneId = (SELECT MilestoneId FROM BugNet_ProjectMilestones WHERE ProjectId = @NewProjectId AND MilestoneName = (SELECT MilestoneName FROM BugNet_ProjectMilestones WHERE MilestoneId = BugNet_DefaultValues.IssueMilestoneId)),
	IssueResolutionId =(SELECT ResolutionId FROM BugNet_ProjectResolutions WHERE ProjectId = @NewProjectId AND ResolutionName = (SELECT ResolutionName FROM BugNet_ProjectResolutions WHERE ResolutionId = BugNet_DefaultValues.IssueResolutionId))
  WHERE ProjectId = @NewProjectId

-- Copy default visiblity
INSERT INTO BugNet_DefaultValuesVisibility
    ([ProjectId]
    ,[StatusVisibility]
    ,[OwnedByVisibility]
    ,[PriorityVisibility]
    ,[AssignedToVisibility]
    ,[PrivateVisibility]
    ,[CategoryVisibility]
    ,[DueDateVisibility]
    ,[TypeVisibility]
    ,[PercentCompleteVisibility]
    ,[MilestoneVisibility]
    ,[EstimationVisibility]
    ,[ResolutionVisibility]
    ,[AffectedMilestoneVisibility]
    ,[StatusEditVisibility]
    ,[OwnedByEditVisibility]
    ,[PriorityEditVisibility]
    ,[AssignedToEditVisibility]
    ,[PrivateEditVisibility]
    ,[CategoryEditVisibility]
    ,[DueDateEditVisibility]
    ,[TypeEditVisibility]
    ,[PercentCompleteEditVisibility]
    ,[MilestoneEditVisibility]
    ,[EstimationEditVisibility]
    ,[ResolutionEditVisibility]
    ,[AffectedMilestoneEditVisibility])
SELECT
    @NewProjectId,
    StatusVisibility,
    OwnedByVisibility,
    PriorityVisibility,
    AssignedToVisibility,
    PrivateVisibility,
    CategoryVisibility,
    DueDateVisibility,
    TypeVisibility,
    PercentCompleteVisibility,
    MilestoneVisibility,
    EstimationVisibility,
    ResolutionVisibility,
    AffectedMilestoneVisibility,
    StatusEditVisibility,
    OwnedByEditVisibility, 
    PriorityEditVisibility, 
    AssignedToEditVisibility,
    PrivateEditVisibility,
    CategoryEditVisibility,
    DueDateEditVisibility, 
    TypeEditVisibility,
    PercentCompleteEditVisibility,
    MilestoneEditVisibility,
    EstimationEditVisibility, 
    ResolutionEditVisibility,
    AffectedMilestoneEditVisibility
FROM
	BugNet_DefaultValuesVisibility
WHERE
	ProjectId = @ProjectId


RETURN @NewProjectId