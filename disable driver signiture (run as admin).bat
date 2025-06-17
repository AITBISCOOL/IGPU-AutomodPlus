:: Disable driver signature enforcement (permanent until re-enabled)
bcdedit /set nointegritychecks on
bcdedit /set testsigning on
shutdown /r /t 0