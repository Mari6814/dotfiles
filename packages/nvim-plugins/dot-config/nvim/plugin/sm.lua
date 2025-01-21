-- Sessionmanager for neovim
-- Features
-- - Store sessions in a global repository
-- - Have a UI to manage sessions
-- - Automatically restore last session on startup or on demand
-- - Automatically save session on exit or on demand
-- - Closing the current session saves it and adds it to the manager UI
-- - Closing nvim while a session is open, the session is saved and restored when opening nvim in a directory that does not have another session defined already
-- - We only want the sessions to be restored automatically when no session is defined for the current directory
-- - We only want to save a session if we open a workspace. If we save everything as a session, then just editing random files would create new sessions permanently
-- - Maybe store recently opened files as some sort of lightweight "recent files" instead of full blown session?

local M = {}

return M
