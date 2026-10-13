-- JSON snapshots must retain exact Double dates/cache values on hosted sessions with float_digits=0.
begin;
alter function staygrubby.open_account_library() set extra_float_digits=3;
notify pgrst,'reload schema';
commit;
