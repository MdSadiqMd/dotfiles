
export PATH="$PATH:$HOME/.sp1/bin"

# ASCII BOAT SHELL INTEGRATION START boat
case ":$PATH:" in
  *":$HOME/.ascii/bin:"*) ;;
  *) PATH="$HOME/.ascii/bin:$PATH" ;;
esac
export PATH
# ASCII BOAT SHELL INTEGRATION END boat
