if [ $fail -eq 0 ]; then
    echo "Tests went through!"
else
    echo "Tests FAILED!"
fi
exit $fail
