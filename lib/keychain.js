import Assistant, {keychain} from './assistant'

// function Put(username, password, service, updateIfExist, callback)
// function Get(username, service, callback)
// function Remove(username, service, callback)


export {SharedKeyChain}

export default class KeyChain {
  constructor(service) {
    Object.defineProperty(this, '__service__', {value: service})
  }

  put(username, password, updateIfExist = true) {
    return new Promise((resolve, reject)=> {
      keychain.Put(username, password, this.__service__, updateIfExist, (error)=> {
        if (error) {
          var err = new Error(error.msg);
          err.code = error.code;
          reject(err);
        }else{
          resolve(this);
        }
      })
    });
  }

  get(username) {
    return new Promise((resolve, reject)=>{
      keychain.Get(username, this.__service__, (error, password)=>{
        if (error) {
          var err = new Error(error.msg);
          err.code = error.code;
          reject(err);
        }else{
          resolve(password);
        }
      });
    });
  }

  remove(username) {
    return new Promise((resolve, reject)=>{
      keychain.Remove(username, this.__service__, (error, password)=>{
        if (error) {
          var err = new Error(error.msg);
          err.code = error.code;
          reject(err);
        }else{
          resolve(password);
        }
      });
    });
  }
}

const SharedKeyChain = new KeyChain();

KeyChain.Put = function (username, password, updateIfExist = true) {
  return SharedKeyChain.put(username, password, updateIfExist);
}
KeyChain.Get = function (username) {
  return SharedKeyChain.get(username);
}
KeyChain.Remove = function (username) {
  return SharedKeyChain.remove(username);
}

SharedKeyChain.put('apikey', '12345678').then(function(){
  return SharedKeyChain.get('apikey');
}).then(function(apikey){
  console.log(apikey);
}).then(function () {
  return SharedKeyChain.remove('apikey');
}).then(function(){
  return SharedKeyChain.get('apikey');
}).then(function(apikey){
  console.log(apikey);
}).catch(function(error){
  console.error(error);
})