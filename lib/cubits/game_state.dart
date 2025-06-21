part of 'game_cubit.dart';

abstract class GameState {}

class GameInitial extends GameState {}

class GameLoading extends GameState {}

class GameRoomLoaded extends GameState {
  final GameRoom room;
  final Player? currentPlayer;
  
  GameRoomLoaded(this.room, this.currentPlayer);
}

class GameError extends GameState {
  final String message;
  GameError(this.message);
} 

